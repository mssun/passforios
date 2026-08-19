//
//  GitRepositoryTest.swift
//  pass
//
//  Created by Mingshen Sun on 1/26/25.
//  Copyright © 2025 Bob Sun. All rights reserved.
//

import Libgit2
import XCTest
@testable import passKit

final class GitRepositoryTest: XCTestCase {
    private var bareRepositoryURL: URL!
    private var workingRepositoryURL: URL!
    private var repository: GitRepository!
    private let fileManager = FileManager.default
    private let checkoutProgressBlock: CheckoutProgressHandler = { _ in
    }

    private let transferProgressBlock: TransferProgressHandler = { _, _ in
    }

    private let pushProgressBlock: PushProgressHandler = { _, _ in
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        bareRepositoryURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        workingRepositoryURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? fileManager.createDirectory(
            at: bareRepositoryURL,
            withIntermediateDirectories: true
        )

        try initializeBareRepository(at: bareRepositoryURL)

        repository = try GitRepository(from: bareRepositoryURL, to: workingRepositoryURL, branchName: "master", transferProgressBlock: transferProgressBlock, checkoutProgressBlock: checkoutProgressBlock)
    }

    func testSetup() {
        let dotGitFileURL = workingRepositoryURL.appendingPathComponent(".git")
        XCTAssertTrue(fileManager.fileExists(atPath: dotGitFileURL.path))
    }

    func testCommitHeadUnborn() throws {
        _ = try repository.commit(name: "name", email: "email@email.com", message: "message")
    }

    func testCommit() throws {
        try commitFiles(["file1", "file2"])
    }

    func testCommitRejectsInvalidSignature() throws {
        XCTAssertThrowsError(try repository.commit(name: "na<me", email: "email@email.com", message: "message"))
    }

    func testPush() throws {
        try testCommit()
        try repository.push(options: GitCredentialOptions(), transferProgressBlock: pushProgressBlock)
    }

    func testGetRecentCommits() throws {
        _ = try repository.commit(name: "name", email: "email@email.com", message: "message1")
        let commit = try repository.getRecentCommits(count: 1)
        XCTAssertEqual(commit.first?.message, "message1")
        XCTAssertEqual(commit.first?.author?.name, "name")
        XCTAssertEqual(commit.first?.author?.email, "email@email.com")
        XCTAssertEqual(commit.first?.sha.count, 40)
    }

    func testNumberOfCommits() throws {
        try commitFiles(["file1", "file2"])
        XCTAssertEqual(repository.numberOfCommits(), 2)
    }

    func testGetLocalCommits() throws {
        try commitFiles(["file1", "file2"])
        try repository.push(options: GitCredentialOptions(), transferProgressBlock: pushProgressBlock)
        XCTAssertEqual(try repository.getLocalCommits().count, 0)

        try commitFiles(["file3", "file4"])
        let commit = try repository.getLocalCommits()
        XCTAssertEqual(commit.first?.message, "message: file4")
        XCTAssertEqual(commit.count, 2)
    }

    func testReset() throws {
        try commitFiles(["file1"])
        try repository.push(options: GitCredentialOptions(), transferProgressBlock: pushProgressBlock)
        try commitFiles(["file2"])
        XCTAssertEqual(try repository.getLocalCommits().count, 1)

        try repository.reset()

        XCTAssertEqual(try repository.getLocalCommits().count, 0)
        XCTAssertFalse(fileManager.fileExists(atPath: workingRepositoryURL.appendingPathComponent("file2").path))
    }

    func testPull() throws {
        try commitFiles(["file1"])
        try repository.push(options: GitCredentialOptions(), transferProgressBlock: pushProgressBlock)

        // A second clone commits and pushes, so that the first one has something to pull.
        let otherURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fileManager.removeItem(at: otherURL) }
        let other = try GitRepository(from: bareRepositoryURL, to: otherURL, branchName: "master", transferProgressBlock: transferProgressBlock, checkoutProgressBlock: checkoutProgressBlock)
        try "change".write(toFile: otherURL.appendingPathComponent("file2").path, atomically: true, encoding: .utf8)
        try other.add(path: "file2")
        _ = try other.commit(name: "name", email: "email@email.com", message: "message: file2")
        try other.push(options: GitCredentialOptions(), transferProgressBlock: pushProgressBlock)

        try repository.pull(options: GitCredentialOptions(), transferProgressBlock: transferProgressBlock)

        XCTAssertTrue(fileManager.fileExists(atPath: workingRepositoryURL.appendingPathComponent("file2").path))
        XCTAssertEqual(try repository.getRecentCommits(count: 1).first?.message, "message: file2")
    }

    /// A pull that cannot be merged has to come back as a conflict listing the
    /// paths, and has to leave a repository that still works. `git_merge` is
    /// given `GIT_CHECKOUT_SAFE`, which writes conflicts into the index and
    /// returns success rather than failing, so the conflict is only noticed if
    /// the index is inspected afterwards.
    func testPullWithConflict() throws {
        try commitFiles(["file1"])
        try repository.push(options: GitCredentialOptions(), transferProgressBlock: pushProgressBlock)

        // A second clone changes file1 and pushes, so the two sides diverge on it.
        let otherURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fileManager.removeItem(at: otherURL) }
        let other = try GitRepository(from: bareRepositoryURL, to: otherURL, branchName: "master", transferProgressBlock: transferProgressBlock, checkoutProgressBlock: checkoutProgressBlock)
        try "theirs".write(toFile: otherURL.appendingPathComponent("file1").path, atomically: true, encoding: .utf8)
        try other.add(path: "file1")
        _ = try other.commit(name: "name", email: "email@email.com", message: "theirs")
        try other.push(options: GitCredentialOptions(), transferProgressBlock: pushProgressBlock)

        try "ours".write(toFile: workingRepositoryURL.appendingPathComponent("file1").path, atomically: true, encoding: .utf8)
        try repository.add(path: "file1")
        _ = try repository.commit(name: "name", email: "email@email.com", message: "ours")

        XCTAssertThrowsError(try repository.pull(options: GitCredentialOptions(), transferProgressBlock: transferProgressBlock)) { error in
            XCTAssertEqual((error as? GitMergeConflictError)?.paths, ["file1"])
        }

        // The half-merged state is undone, so committing still works and file1
        // holds our side rather than conflict markers.
        XCTAssertEqual(try String(contentsOf: workingRepositoryURL.appendingPathComponent("file1"), encoding: .utf8), "ours")
        try commitFiles(["file2"])
    }

    func testPullUpToDate() throws {
        try commitFiles(["file1"])
        try repository.push(options: GitCredentialOptions(), transferProgressBlock: pushProgressBlock)
        try repository.pull(options: GitCredentialOptions(), transferProgressBlock: transferProgressBlock)
        XCTAssertEqual(repository.numberOfCommits(), 1)
    }

    func testCheckoutAndChangeBranch() throws {
        try commitFiles(["file1"])
        try repository.push(options: GitCredentialOptions(), transferProgressBlock: pushProgressBlock)
        try createAndPushBranch(named: "feature-branch", deleteLocally: false)

        try repository.checkoutAndChangeBranch(branchName: "feature-branch", progressBlock: checkoutProgressBlock)
    }

    /// The branch only exists on the remote, so it has to be created locally and set to track it.
    func testCheckoutAndChangeToRemoteOnlyBranch() throws {
        try commitFiles(["file1"])
        try repository.push(options: GitCredentialOptions(), transferProgressBlock: pushProgressBlock)
        try createAndPushBranch(named: "feature-branch", deleteLocally: true)

        try repository.checkoutAndChangeBranch(branchName: "feature-branch", progressBlock: checkoutProgressBlock)

        // Tracking the remote branch is what makes local commits discoverable.
        XCTAssertEqual(try repository.getLocalCommits().count, 0)
    }

    func testCheckoutUnknownBranch() throws {
        try commitFiles(["file1"])
        XCTAssertThrowsError(try repository.checkoutAndChangeBranch(branchName: "nowhere", progressBlock: checkoutProgressBlock))
    }

    func testRm() throws {
        try commitFiles(["file1", "file2"])

        try repository.rm(path: "file1")
        let commit = try repository.commit(name: "name", email: "email@email.com", message: "message: remove file1")
        XCTAssertEqual(commit.message, "message: remove file1")
        XCTAssertFalse(fileManager.fileExists(atPath: workingRepositoryURL.appendingPathComponent("file1").path))
    }

    func testMv() throws {
        try commitFiles(["file1", "file2"])

        try repository.mv(from: "file1", to: "file3")
        let commit = try repository.commit(name: "name", email: "email@email.com", message: "message: remove file1")
        XCTAssertEqual(commit.message, "message: remove file1")
        XCTAssertFalse(fileManager.fileExists(atPath: workingRepositoryURL.appendingPathComponent("file1").path))
        XCTAssertTrue(fileManager.fileExists(atPath: workingRepositoryURL.appendingPathComponent("file3").path))
    }

    func testLastCommitDate() throws {
        let before = Date()
        try commitFiles(["file1"])
        let date = try repository.lastCommitDate(path: "file1")
        // Commit times have a resolution of one second.
        XCTAssertGreaterThanOrEqual(date.timeIntervalSince1970, before.timeIntervalSince1970 - 1)
    }

    /// The date has to come from the last commit that touched the path, not the
    /// last commit in the repository.
    func testLastCommitDateIgnoresCommitsToOtherPaths() throws {
        try commitFiles(["file1"])
        let afterFirst = try repository.lastCommitDate(path: "file1")

        // A later commit that leaves file1 alone must not move its date.
        try commitFiles(["file2"])
        XCTAssertEqual(try repository.lastCommitDate(path: "file1"), afterFirst)
        XCTAssertGreaterThanOrEqual(
            try repository.lastCommitDate(path: "file2").timeIntervalSince1970,
            afterFirst.timeIntervalSince1970
        )

        // Changing it again does move it.
        try "changed".write(toFile: workingRepositoryURL.appendingPathComponent("file1").path, atomically: true, encoding: .utf8)
        try repository.add(path: "file1")
        _ = try repository.commit(name: "name", email: "email@email.com", message: "edit file1")
        XCTAssertGreaterThanOrEqual(
            try repository.lastCommitDate(path: "file1").timeIntervalSince1970,
            afterFirst.timeIntervalSince1970
        )
    }

    func testLastCommitDateOfUnknownPath() throws {
        try commitFiles(["file1"])
        XCTAssertEqual(try repository.lastCommitDate(path: "never-committed"), Date(timeIntervalSince1970: 0))
    }

    func testNumberOfLocalCommits() throws {
        try commitFiles(["file1"])
        try repository.push(options: GitCredentialOptions(), transferProgressBlock: pushProgressBlock)
        XCTAssertEqual(try repository.numberOfLocalCommits(), 0)

        try commitFiles(["file2", "file3"])
        XCTAssertEqual(try repository.numberOfLocalCommits(), 2)
    }

    func testResetReportsWhatItDiscarded() throws {
        try commitFiles(["file1"])
        try repository.push(options: GitCredentialOptions(), transferProgressBlock: pushProgressBlock)
        try commitFiles(["file2", "file3"])

        XCTAssertEqual(try repository.reset(), 2)
        XCTAssertEqual(try repository.numberOfLocalCommits(), 0)
        XCTAssertEqual(try repository.reset(), 0)
    }

    override func tearDownWithError() throws {
        repository = nil
        try fileManager.removeItem(at: bareRepositoryURL)
        try fileManager.removeItem(at: workingRepositoryURL)
        super.tearDown()
    }

    // MARK: - Fixtures built with the libgit2 C API

    private func commitFiles(_ filenames: [String]) throws {
        try filenames.forEach { filename in
            let fileURL = workingRepositoryURL.appendingPathComponent(filename)
            try "change".write(toFile: fileURL.path, atomically: true, encoding: .utf8)
            try repository.add(path: filename)
            _ = try repository.commit(name: "name", email: "email@email.com", message: "message: \(filename)")
        }
    }

    private func initializeBareRepository(at url: URL) throws {
        initializeLibgit2()
        var options = git_repository_init_options()
        try gitTry(git_repository_init_options_init(&options, UInt32(GIT_REPOSITORY_INIT_OPTIONS_VERSION)))
        options.flags = GIT_REPOSITORY_INIT_BARE.rawValue
        var repository: OpaquePointer?
        try gitTry(git_repository_init_ext(&repository, url.path, &options))
        git_repository_free(repository)
    }

    private func createAndPushBranch(named name: String, deleteLocally: Bool) throws {
        var repository: OpaquePointer?
        try gitTry(git_repository_open(&repository, workingRepositoryURL.path))
        defer { git_repository_free(repository) }

        var head: OpaquePointer?
        try gitTry(git_repository_head(&head, repository))
        defer { git_reference_free(head) }
        var headCommit: OpaquePointer?
        try gitTry(git_reference_peel(&headCommit, head, GIT_OBJECT_COMMIT))
        defer { git_commit_free(headCommit) }

        var branch: OpaquePointer?
        try gitTry(git_branch_create(&branch, repository, name, headCommit, 0))
        defer { git_reference_free(branch) }

        var remote: OpaquePointer?
        try gitTry(git_remote_lookup(&remote, repository, "origin"))
        defer { git_remote_free(remote) }
        var options = git_push_options()
        try gitTry(git_push_options_init(&options, UInt32(GIT_PUSH_OPTIONS_VERSION)))
        try "refs/heads/\(name):refs/heads/\(name)".withCString { refspec in
            var refspecs: [UnsafeMutablePointer<CChar>?] = [UnsafeMutablePointer(mutating: refspec)]
            try refspecs.withUnsafeMutableBufferPointer { buffer in
                var array = git_strarray(strings: buffer.baseAddress, count: 1)
                try gitTry(git_remote_push(remote, &array, &options))
            }
        }

        if deleteLocally {
            try gitTry(git_branch_delete(branch))
        }
    }
}
