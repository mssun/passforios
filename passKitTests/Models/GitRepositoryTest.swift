//
//  GitRepositoryTest.swift
//  pass
//
//  Created by Mingshen Sun on 1/26/25.
//  Copyright © 2025 Bob Sun. All rights reserved.
//

import ObjectiveGit
import XCTest
@testable import passKit

final class GitRepositoryTest: XCTestCase {
    private var bareRepositoryURL: URL!
    private var workingRepositoryURL: URL!
    private var repository: GitRepository!
    private let fileManager = FileManager.default
    private let checkoutProgressBlock: CheckoutProgressHandler = { _, _, _ in
    }

    private let transferProgressBlock: TransferProgressHandler = { _, _ in
    }

    private let pushProgressBlock: PushProgressHandler = { _, _, _, _ in
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

        let options = [
            GTRepositoryInitOptionsFlags: GTRepositoryInitFlags.bare.rawValue,
        ]
        try GTRepository.initializeEmpty(atFileURL: bareRepositoryURL, options: options)

        repository = try GitRepository(from: bareRepositoryURL, to: workingRepositoryURL, branchName: "master", options: options, transferProgressBlock: transferProgressBlock, checkoutProgressBlock: checkoutProgressBlock)
    }

    func testSetup() {
        let dotGitFileURL = workingRepositoryURL.appendingPathComponent(".git")
        XCTAssertTrue(fileManager.fileExists(atPath: dotGitFileURL.path))
    }

    func testCommitHeadUnborn() throws {
        _ = try repository.commit(name: "name", email: "email@email.com", message: "message")
    }

    func testCommit() throws {
        try ["file1", "file2"].forEach { filename in
            let fileURL = workingRepositoryURL.appendingPathComponent(filename)
            try "change1".write(toFile: fileURL.path, atomically: true, encoding: .utf8)
            try repository.add(path: filename)
            _ = try repository.commit(name: "name", email: "email@email.com", message: "message: \(filename)")
        }
    }

    func testPush() throws {
        try testCommit()
        let options: [String: Any] = [:]
        try repository.push(options: options, transferProgressBlock: pushProgressBlock)
    }

    func testGetRecentCommits() throws {
        _ = try repository.commit(name: "name", email: "email@email.com", message: "message1")
        let commit = try repository.getRecentCommits(count: 1)
        XCTAssertEqual(commit.first?.message, "message1")
    }

    func testGetLocalCommits() throws {
        try ["file1", "file2"].forEach { filename in
            let fileURL = workingRepositoryURL.appendingPathComponent(filename)
            try "change".write(toFile: fileURL.path, atomically: true, encoding: .utf8)
            try repository.add(path: filename)
            _ = try repository.commit(name: "name", email: "email@email.com", message: "message: \(filename)")
        }
        let options: [String: Any] = [:]
        try repository.push(options: options, transferProgressBlock: pushProgressBlock)
        try ["file3", "file4"].forEach { filename in
            let fileURL = workingRepositoryURL.appendingPathComponent(filename)
            try "change".write(toFile: fileURL.path, atomically: true, encoding: .utf8)
            try repository.add(path: filename)
            _ = try repository.commit(name: "name", email: "email@email.com", message: "message: \(filename)")
        }
        let commit = try repository.getLocalCommits()
        XCTAssertEqual(commit.first?.message, "message: file4")
    }

    func testCheckoutAndChangeBranch() throws {
        _ = try repository.commit(name: "name", email: "email@email.com", message: "message")
        let repo = repository.repository
        let branchName = "feature-branch"
        let head = try repo.headReference()
        let branch = try repo.createBranchNamed(branchName, from: head.targetOID!, message: nil)
        let remote = try GTRemote(name: "origin", in: repo)
        try repo.pushBranches([branch], to: remote)

        try repository.checkoutAndChangeBranch(branchName: "feature-branch", progressBlock: checkoutProgressBlock)
    }

    func testRm() throws {
        try ["file1", "file2"].forEach { filename in
            let fileURL = workingRepositoryURL.appendingPathComponent(filename)
            try "change1".write(toFile: fileURL.path, atomically: true, encoding: .utf8)
            try repository.add(path: filename)
            _ = try repository.commit(name: "name", email: "email@email.com", message: "message: add \(filename)")
        }

        try repository.rm(path: "file1")
        let commit = try repository.commit(name: "name", email: "email@email.com", message: "message: remove file1")
        XCTAssertEqual(commit.message, "message: remove file1")
        XCTAssertFalse(fileManager.fileExists(atPath: workingRepositoryURL.appendingPathComponent("file1").path))
    }

    func testMv() throws {
        try ["file1", "file2"].forEach { filename in
            let fileURL = workingRepositoryURL.appendingPathComponent(filename)
            try "change1".write(toFile: fileURL.path, atomically: true, encoding: .utf8)
            try repository.add(path: filename)
            _ = try repository.commit(name: "name", email: "email@email.com", message: "message: add \(filename)")
        }

        try repository.mv(from: "file1", to: "file3")
        let commit = try repository.commit(name: "name", email: "email@email.com", message: "message: remove file1")
        XCTAssertEqual(commit.message, "message: remove file1")
        XCTAssertFalse(fileManager.fileExists(atPath: workingRepositoryURL.appendingPathComponent("file1").path))
        XCTAssertTrue(fileManager.fileExists(atPath: workingRepositoryURL.appendingPathComponent("file3").path))
    }

    override func tearDownWithError() throws {
        try fileManager.removeItem(at: bareRepositoryURL)
        try fileManager.removeItem(at: workingRepositoryURL)
        super.tearDown()
    }
}
