//
//  GitTransportTest.swift
//  passKitTests
//
//  Created by Mingshen Sun on 8/4/26.
//  Copyright © 2026 Bob Sun. All rights reserved.
//

import XCTest
@testable import passKit

/// Exercises the SSH and HTTPS transports against the servers started by
/// scripts/git_servers.sh. Every other test talks to a repository on disk, so
/// without these nothing covers libssh2, the TLS stream of libgit2 or the
/// credential callbacks that only remote operations reach.
///
/// The tests skip when the script has not been run, so that `fastlane test`
/// still works without it.
final class GitTransportTest: XCTestCase {
    private let fileManager = FileManager.default
    private var workingDirectory: URL!

    private let noProgress: TransferProgressHandler = { _, _ in }
    private let noCheckoutProgress: CheckoutProgressHandler = { _ in }
    private let noPushProgress: PushProgressHandler = { _, _ in }

    private var environment: [String: String] { ProcessInfo.processInfo.environment }

    override func setUpWithError() throws {
        try super.setUpWithError()
        workingDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        // The certificate of the test server is pinned rather than added to the
        // trust store of the simulator, which cannot be relied on: simctl
        // reports success and the trust does not take effect everywhere.
        gitPinnedCertificate = environment["GIT_HTTPS_CERTIFICATE_BASE64"].flatMap { Data(base64Encoded: $0) }
    }

    override func tearDownWithError() throws {
        gitPinnedCertificate = nil
        try? fileManager.removeItem(at: workingDirectory)
        try super.tearDownWithError()
    }

    // MARK: - HTTPS

    func testClonesOverHTTPS() throws {
        let repository = try cloneOverHTTPS()
        XCTAssertTrue(fileManager.fileExists(atPath: workingDirectory.appendingPathComponent("README").path))
        XCTAssertTrue(try containsSeedCommit(repository))
    }

    func testPushesOverHTTPS() throws {
        let repository = try cloneOverHTTPS()
        try commitFile(named: "over-https", in: repository)
        try repository.push(options: try httpsCredentials(), transferProgressBlock: noPushProgress)
        XCTAssertEqual(try repository.getLocalCommits().count, 0)
    }

    func testPullsOverHTTPS() throws {
        let repository = try cloneOverHTTPS()
        try repository.pull(options: try httpsCredentials(), transferProgressBlock: noProgress)
        XCTAssertTrue(try containsSeedCommit(repository))
    }

    /// The wrong password must fail rather than hang, and must not be retried forever.
    func testRejectsWrongHTTPSPassword() throws {
        let url = try requireURL("GIT_HTTPS_URL")
        let userName = try requireValue("GIT_HTTPS_USER")
        let options = GitCredentialOptions(credentialProvider: provider(userName: userName, attempts: 1) {
            .userPassPlaintext(userName: userName, password: "definitely-not-the-password")
        })
        XCTAssertThrowsError(try clone(from: url, options: options)) { error in
            // Otherwise this passes without proving anything whenever the server
            // is unreachable or its certificate is not trusted.
            XCTAssertFalse(
                error.localizedDescription.contains("untrusted"),
                "the connection itself failed, so nothing about the password was tested: \(error.localizedDescription)"
            )
        }
    }

    /// The pin accepts one certificate, not any certificate: a server presenting
    /// something else has to be refused.
    func testRejectsUnpinnedCertificate() throws {
        let url = try requireURL("GIT_HTTPS_URL")
        _ = try requireValue("GIT_HTTPS_CERTIFICATE_BASE64")
        gitPinnedCertificate = Data("not the certificate of the server".utf8)

        XCTAssertThrowsError(try clone(from: url, options: try httpsCredentials())) { error in
            XCTAssertTrue(
                error.localizedDescription.contains("untrusted"),
                "expected the connection to be refused, got: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - SSH

    func testClonesOverSSH() throws {
        let repository = try cloneOverSSH()
        XCTAssertTrue(fileManager.fileExists(atPath: workingDirectory.appendingPathComponent("README").path))
        XCTAssertTrue(try containsSeedCommit(repository))
    }

    func testPushesOverSSH() throws {
        let repository = try cloneOverSSH()
        try commitFile(named: "over-ssh", in: repository)
        try repository.push(options: try sshCredentials(), transferProgressBlock: noPushProgress)
        XCTAssertEqual(try repository.getLocalCommits().count, 0)
    }

    func testPullsOverSSH() throws {
        let repository = try cloneOverSSH()
        try repository.pull(options: try sshCredentials(), transferProgressBlock: noProgress)
        XCTAssertTrue(try containsSeedCommit(repository))
    }

    /// A provider that gives up stands for the user dismissing the passphrase
    /// prompt. libgit2 must report that rather than a message left over from
    /// something else.
    func testReportsCancelledAuthentication() throws {
        let url = try requireURL("GIT_SSH_URL")
        let options = GitCredentialOptions(credentialProvider: provider(userName: "git", attempts: 0) { nil })

        XCTAssertThrowsError(try clone(from: url, options: options)) { error in
            XCTAssertFalse(
                error.localizedDescription.contains("Git error"),
                "expected a described failure, got: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Fixtures

    private func cloneOverHTTPS() throws -> GitRepository {
        try clone(from: try requireURL("GIT_HTTPS_URL"), options: try httpsCredentials())
    }

    private func cloneOverSSH() throws -> GitRepository {
        try clone(from: try requireURL("GIT_SSH_URL"), options: try sshCredentials())
    }

    private func clone(from url: URL, options: GitCredentialOptions) throws -> GitRepository {
        try GitRepository(
            from: url,
            to: workingDirectory,
            branchName: "master",
            options: options,
            transferProgressBlock: noProgress,
            checkoutProgressBlock: noCheckoutProgress
        )
    }

    private func httpsCredentials() throws -> GitCredentialOptions {
        let userName = try requireValue("GIT_HTTPS_USER")
        let password = try requireValue("GIT_HTTPS_PASSWORD")
        return GitCredentialOptions(credentialProvider: provider(userName: userName, attempts: 1) {
            .userPassPlaintext(userName: userName, password: password)
        })
    }

    private func sshCredentials() throws -> GitCredentialOptions {
        let userName = try requireValue("GIT_SSH_USER")
        let encodedKey = try requireValue("GIT_SSH_PRIVATE_KEY_BASE64")
        let privateKey = try XCTUnwrap(Data(base64Encoded: encodedKey).flatMap { String(data: $0, encoding: .utf8) })
        return GitCredentialOptions(credentialProvider: provider(userName: userName, attempts: 1) {
            .sshKeyMemory(userName: userName, publicKey: nil, privateKey: privateKey, passphrase: "")
        })
    }

    /// libgit2 asks until it is authenticated or the provider stops, so the
    /// number of attempts has to be bounded or a rejection loops.
    private func provider(userName: String, attempts: Int, credential: @escaping () -> GitCredentialSpec?) -> GitCredentialProvider {
        var remaining = attempts
        return GitCredentialProvider(userName: userName) {
            guard remaining > 0 else {
                return nil
            }
            remaining -= 1
            return credential()
        }
    }

    /// The push tests add to the same repositories, so nothing may assume that
    /// the seeded commit is still the most recent one.
    private func containsSeedCommit(_ repository: GitRepository) throws -> Bool {
        try repository.getRecentCommits(count: 50).contains { $0.message?.trimmed == "seed" }
    }

    private func commitFile(named name: String, in repository: GitRepository) throws {
        try "content".write(to: workingDirectory.appendingPathComponent(name), atomically: true, encoding: .utf8)
        try repository.add(path: name)
        _ = try repository.commit(name: "Test", email: "test@example.com", message: "add \(name)")
    }

    private func requireValue(_ name: String) throws -> String {
        guard let value = environment[name], !value.isEmpty else {
            throw XCTSkip("\(name) is not set; run scripts/git_servers.sh start and source .git-servers/env")
        }
        return value
    }

    private func requireURL(_ name: String) throws -> URL {
        // Resolved before the unwrap: XCTUnwrap catches a skip thrown inside its
        // closure and records it as a failure of its own.
        let value = try requireValue(name)
        return try XCTUnwrap(URL(string: value))
    }
}
