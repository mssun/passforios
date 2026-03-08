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
    private let remoteRepoURL: URL = Bundle(for: PasswordStoreTest.self).resourceURL!.appendingPathComponent("Fixtures/password-store.git")
    private let localRepoURL: URL = Globals.sharedContainerURL.appendingPathComponent("Library/password-store-test/")

    private var passwordStore: PasswordStore! = nil

    override func setUp() {
        passwordStore = PasswordStore(url: localRepoURL)
    }

    override func tearDown() {
        passwordStore.erase()
        passwordStore = nil
    }

    func testInitPasswordEntityCoreData() throws {
        try cloneRepository()

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

    func testCloneAndDecryptMultiKeys() throws {
        try cloneRepository()

        Defaults.isEnableGPGIDOn = true
        defer {
            Defaults.isEnableGPGIDOn = false
        }

        [
            ("work/github.com", "4712286271220DB299883EA7062E678DA1024DAE"),
            ("personal/github.com", "787EAE1A5FA3E749AA34CC6AA0645EBED862027E"),
        ].forEach { path, id in
            let keyID = findGPGID(from: localRepoURL.appendingPathComponent(path))
            XCTAssertEqual(keyID, id)
        }

        let keychain = AppKeychain.shared
        try KeyFileManager(keyType: PGPKey.PUBLIC, keyPath: "", keyHandler: keychain.add).importKey(from: RSA2048_RSA4096.publicKeys)
        try KeyFileManager(keyType: PGPKey.PRIVATE, keyPath: "", keyHandler: keychain.add).importKey(from: RSA2048_RSA4096.privateKeys)
        try PGPAgent.shared.initKeys()

        let personal = try decrypt(passwordStore: passwordStore, path: "personal/github.com.gpg", passphrase: "passforios")
        XCTAssertEqual(personal.plainText, "passwordforpersonal\n")

        let work = try decrypt(passwordStore: passwordStore, path: "work/github.com.gpg", passphrase: "passforios")
        XCTAssertEqual(work.plainText, "passwordforwork\n")

        let testPassword = Password(name: "test", path: "test.gpg", plainText: "testpassword")
        let testPasswordEntity = try passwordStore.add(password: testPassword)!
        let testPasswordPlain = try passwordStore.decrypt(passwordEntity: testPasswordEntity, requestPGPKeyPassphrase: requestPGPKeyPassphrase)
        XCTAssertEqual(testPasswordPlain.plainText, "testpassword")
    }

    fileprivate func cloneRepository() throws {
        try passwordStore.cloneRepository(remoteRepoURL: remoteRepoURL, branchName: "master")
        expectation(for: NSPredicate { _, _ in FileManager.default.fileExists(atPath: self.localRepoURL.path) }, evaluatedWith: nil)
        waitForExpectations(timeout: 3, handler: nil)
    }

    fileprivate func decrypt(passwordStore: PasswordStore, path: String, passphrase _: String) throws -> Password {
        let entity = passwordStore.fetchPasswordEntity(with: path)!
        return try passwordStore.decrypt(passwordEntity: entity, requestPGPKeyPassphrase: requestPGPKeyPassphrase)
    }
}
