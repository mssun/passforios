//
//  PasswordStoreTest.swift
//  passKitTests
//
//  Created by Mingshen Sun on 13/4/2020.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import Foundation
import ObjectiveGit
import XCTest

@testable import passKit

final class PasswordStoreTest: XCTestCase {
    private let localRepoURL: URL = Globals.sharedContainerURL.appendingPathComponent("Library/password-store-test/")

    private var passwordStore: PasswordStore! = nil

    override func setUp() {
        passwordStore = PasswordStore(url: localRepoURL)
    }

    override func tearDown() {
        passwordStore.erase()
        passwordStore = nil

        Defaults.removeAll()
    }

    func testInitPasswordEntityCoreData() throws {
        try cloneRepository(.withGPGID)

        XCTAssertEqual(passwordStore.numberOfPasswords, 4)

        let entity = passwordStore.fetchPasswordEntity(with: "personal/github.com.gpg")
        XCTAssertEqual(entity!.path, "personal/github.com.gpg")
        XCTAssertEqual(entity!.name, "github.com")
        XCTAssertTrue(entity!.isSynced)
        XCTAssertEqual(entity!.parent!.name, "personal")

        XCTAssertNotNil(passwordStore.fetchPasswordEntity(with: "family/amazon.com.gpg"))
        XCTAssertNotNil(passwordStore.fetchPasswordEntity(with: "work/github.com.gpg"))
        XCTAssertNotNil(passwordStore.fetchPasswordEntity(with: "shared/github.com.gpg"))

        let dirEntity = passwordStore.fetchPasswordEntity(with: "shared")
        XCTAssertNotNil(dirEntity)
        XCTAssertTrue(dirEntity!.isDir)
        XCTAssertEqual(dirEntity!.name, "shared")
        XCTAssertEqual(dirEntity!.children.count, 1)
    }

    func testEraseStoreData() throws {
        try cloneRepository(.withGPGID)
        XCTAssertTrue(FileManager.default.fileExists(atPath: localRepoURL.path))
        XCTAssertGreaterThan(passwordStore.numberOfPasswords, 0)
        XCTAssertNotNil(passwordStore.gitRepository)

        passwordStore.eraseStoreData()

        XCTAssertFalse(FileManager.default.fileExists(atPath: localRepoURL.path))
        XCTAssertEqual(passwordStore.numberOfPasswords, 0)
        XCTAssertNil(passwordStore.gitRepository)
    }

    func testErase() throws {
        try cloneRepository(.withGPGID)
        try importSinglePGPKey()
        Defaults.gitSignatureName = "Test User"
        PasscodeLock.shared.save(passcode: "1234")

        XCTAssertGreaterThan(passwordStore.numberOfPasswords, 0)
        XCTAssertTrue(AppKeychain.shared.contains(key: PGPKey.PUBLIC.getKeychainKey()))
        XCTAssertEqual(Defaults.gitSignatureName, "Test User")
        XCTAssertTrue(PasscodeLock.shared.hasPasscode)
        XCTAssertTrue(PGPAgent.shared.isInitialized)

        passwordStore.erase()

        XCTAssertEqual(passwordStore.numberOfPasswords, 0)
        XCTAssertFalse(AppKeychain.shared.contains(key: PGPKey.PUBLIC.getKeychainKey()))
        XCTAssertFalse(Defaults.hasKey(\.gitSignatureName))
        XCTAssertFalse(PasscodeLock.shared.hasPasscode)
        XCTAssertFalse(PGPAgent.shared.isInitialized)
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testFetchPasswordEntityCoreDataByParent() throws {
        try cloneRepository(.withGPGID)

        let rootChildren = passwordStore.fetchPasswordEntityCoreData(parent: nil)
        XCTAssertGreaterThan(rootChildren.count, 0)
        rootChildren.forEach { entity in
            XCTAssertTrue(entity.isDir)
        }

        let personalDir = passwordStore.fetchPasswordEntity(with: "personal")
        let personalChildren = passwordStore.fetchPasswordEntityCoreData(parent: personalDir)
        XCTAssertEqual(personalChildren.count, 1)
        XCTAssertEqual(personalChildren.first?.name, "github.com")
    }

    func testFetchPasswordEntityCoreDataWithDir() throws {
        try cloneRepository(.withGPGID)

        let allPasswords = passwordStore.fetchPasswordEntityCoreData(withDir: false)
        XCTAssertEqual(allPasswords.count, 4)
        allPasswords.forEach { entity in
            XCTAssertFalse(entity.isDir)
        }
    }

    func testEncryptSaveDecryptMultiline() throws {
        try cloneRepository(.empty)
        try importSinglePGPKey()

        let password = Password(name: "test", path: "test.gpg", plainText: "foobar\nwith\nmultiple\nlines")
        _ = try passwordStore.add(password: password)
        let decryptedPassword = try decrypt(path: "test.gpg")
        XCTAssertEqual(decryptedPassword.plainText, "foobar\nwith\nmultiple\nlines")
    }

    func testCloneAndDecryptMultiKeys() throws {
        try cloneRepository(.withGPGID)
        try importMultiplePGPKeys()

        Defaults.isEnableGPGIDOn = true

        [
            ("work/github.com", "4712286271220DB299883EA7062E678DA1024DAE"),
            ("personal/github.com", "787EAE1A5FA3E749AA34CC6AA0645EBED862027E"),
        ].forEach { path, id in
            let keyID = findGPGID(from: localRepoURL.appendingPathComponent(path))
            XCTAssertEqual(keyID, id)
        }

        let personal = try decrypt(path: "personal/github.com.gpg")
        XCTAssertEqual(personal.plainText, "passwordforpersonal\n")

        let work = try decrypt(path: "work/github.com.gpg")
        XCTAssertEqual(work.plainText, "passwordforwork\n")

        let testPassword = Password(name: "test", path: "test.gpg", plainText: "testpassword")
        let testPasswordEntity = try passwordStore.add(password: testPassword)!
        let testPasswordPlain = try passwordStore.decrypt(passwordEntity: testPasswordEntity, requestPGPKeyPassphrase: requestPGPKeyPassphrase)
        XCTAssertEqual(testPasswordPlain.plainText, "testpassword")
    }

    // MARK: - Helpers

    private enum RemoteRepo {
        case empty
        case withGPGID

        var url: URL {
            switch self {
            case .empty:
                Bundle(for: PasswordStoreTest.self).resourceURL!.appendingPathComponent("Fixtures/password-store-empty.git")
            case .withGPGID:
                Bundle(for: PasswordStoreTest.self).resourceURL!.appendingPathComponent("Fixtures/password-store-with-gpgid.git")
            }
        }

        var branchName: String {
            switch self {
            case .empty:
                "main"
            case .withGPGID:
                "master"
            }
        }
    }

    private func cloneRepository(_ remote: RemoteRepo) throws {
        try passwordStore.cloneRepository(remoteRepoURL: remote.url, branchName: remote.branchName)
        expectation(for: NSPredicate { _, _ in FileManager.default.fileExists(atPath: self.localRepoURL.path) }, evaluatedWith: nil)
        waitForExpectations(timeout: 3, handler: nil)
    }

    private func importSinglePGPKey() throws {
        let keychain = AppKeychain.shared
        try KeyFileManager(keyType: PGPKey.PUBLIC, keyPath: "", keyHandler: keychain.add).importKey(from: RSA4096.publicKey)
        try KeyFileManager(keyType: PGPKey.PRIVATE, keyPath: "", keyHandler: keychain.add).importKey(from: RSA4096.privateKey)
        try PGPAgent.shared.initKeys()
    }

    private func importMultiplePGPKeys() throws {
        let keychain = AppKeychain.shared
        try KeyFileManager(keyType: PGPKey.PUBLIC, keyPath: "", keyHandler: keychain.add).importKey(from: RSA2048_RSA4096.publicKeys)
        try KeyFileManager(keyType: PGPKey.PRIVATE, keyPath: "", keyHandler: keychain.add).importKey(from: RSA2048_RSA4096.privateKeys)
        try PGPAgent.shared.initKeys()
    }

    private func decrypt(path: String, keyID: String? = nil) throws -> Password {
        let entity = passwordStore.fetchPasswordEntity(with: path)!
        return try passwordStore.decrypt(passwordEntity: entity, keyID: keyID, requestPGPKeyPassphrase: requestPGPKeyPassphrase)
    }
}
