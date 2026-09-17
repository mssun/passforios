//
//  PasswordStoreCloneStagingTest.swift
//  passKitTests
//

import Foundation
import XCTest

@testable import passKit

final class PasswordStoreCloneStagingTest: XCTestCase {
    private var root: URL!
    private var sharedContainer: URL!
    private var destination: URL!
    private var staging: URL!
    private var keyFile: URL!

    private let fileManager = FileManager.default

    override func setUpWithError() throws {
        try super.setUpWithError()

        root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        sharedContainer = root.appendingPathComponent("shared", isDirectory: true)
        destination = sharedContainer.appendingPathComponent("Library/password-store", isDirectory: true)
        staging = root.appendingPathComponent("private/tmp/incoming-password-store", isDirectory: true)
        keyFile = sharedContainer.appendingPathComponent("Documents/gpg_key")

        try fileManager.createDirectory(at: keyFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: staging.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "USER PRIVATE KEY".write(to: keyFile, atomically: true, encoding: .utf8)
    }

    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: root)
        try super.tearDownWithError()
    }

    private func keyFileContents() -> String? {
        try? String(contentsOf: keyFile, encoding: .utf8)
    }

    /// Mimics a checkout that writes outside the directory it was given.
    private func hostileClone(into directory: URL) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try "entry".write(to: directory.appendingPathComponent("entry.gpg"), atomically: true, encoding: .utf8)

        let escaped = URL(fileURLWithPath: directory.path + "/../../Documents/gpg_key").standardized
        try? fileManager.createDirectory(at: escaped.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? "ATTACKER KEY".write(to: escaped, atomically: true, encoding: .utf8)
    }

    private func benignClone(into directory: URL) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try "entry".write(to: directory.appendingPathComponent("entry.gpg"), atomically: true, encoding: .utf8)
    }

    func testCloneCannotReachTheKeyFilesNextToTheStore() throws {
        try PasswordStore.cloneViaStaging(
            staging: staging,
            destination: destination,
            fileManager: fileManager,
            clone: hostileClone
        )

        XCTAssertEqual(keyFileContents(), "USER PRIVATE KEY")
        XCTAssertTrue(fileManager.fileExists(atPath: destination.appendingPathComponent("entry.gpg").path))
        XCTAssertFalse(fileManager.fileExists(atPath: staging.path))
    }

    func testCloneEndsUpInTheStore() throws {
        try PasswordStore.cloneViaStaging(
            staging: staging,
            destination: destination,
            fileManager: fileManager,
            clone: benignClone
        )

        let entry = destination.appendingPathComponent("entry.gpg")
        XCTAssertEqual(try String(contentsOf: entry, encoding: .utf8), "entry")
        XCTAssertFalse(fileManager.fileExists(atPath: staging.path))
    }

    func testCloneReplacesAnExistingStore() throws {
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        try "stale".write(to: destination.appendingPathComponent("stale.gpg"), atomically: true, encoding: .utf8)

        try PasswordStore.cloneViaStaging(
            staging: staging,
            destination: destination,
            fileManager: fileManager,
            clone: benignClone
        )

        XCTAssertTrue(fileManager.fileExists(atPath: destination.appendingPathComponent("entry.gpg").path))
        XCTAssertFalse(fileManager.fileExists(atPath: destination.appendingPathComponent("stale.gpg").path))
    }

    func testFailedCloneLeavesNothingBehind() throws {
        struct CloneFailure: Error {}

        XCTAssertThrowsError(
            try PasswordStore.cloneViaStaging(
                staging: staging,
                destination: destination,
                fileManager: fileManager
            ) { directory in
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                throw CloneFailure()
            }
        )

        XCTAssertFalse(fileManager.fileExists(atPath: destination.path))
        XCTAssertFalse(fileManager.fileExists(atPath: staging.path))
    }
}
