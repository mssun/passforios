//
//  PasswordStoreTest.swift
//  passKitTests
//
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import Foundation
import ObjectiveGit
import XCTest

@testable import passKit

class PasswordStoreTest: XCTestCase {
    private let remoteRepoURL = URL(string: "https://github.com/mssun/passforios-password-store.git")!

    func testCloneAndDecryptMultiKeys() throws {
        let url = URL(fileURLWithPath: "\(Globals.repositoryPath)-test")
        let passwordStore = PasswordStore(url: url)
        try passwordStore.cloneRepository(remoteRepoURL: remoteRepoURL, branchName: "master")
        expectation(for: NSPredicate { _, _ in FileManager.default.fileExists(atPath: url.path) }, evaluatedWith: nil)
        waitForExpectations(timeout: 3, handler: nil)

        [
            ("work/github.com", "4712286271220DB299883EA7062E678DA1024DAE"),
            ("personal/github.com", "787EAE1A5FA3E749AA34CC6AA0645EBED862027E"),
        ].forEach { path, id in
            let keyID = findGPGID(from: url.appendingPathComponent(path))
            XCTAssertEqual(keyID, id)
        }

        let keychain = AppKeychain.shared
        try KeyFileManager(keyType: PgpKey.PUBLIC, keyPath: "", keyHandler: keychain.add).importKey(from: RSA2048_RSA4096.publicKeys)
        try KeyFileManager(keyType: PgpKey.PRIVATE, keyPath: "", keyHandler: keychain.add).importKey(from: RSA2048_RSA4096.privateKeys)
        try PGPAgent.shared.initKeys()

        let personal = try decrypt(passwordStore: passwordStore, path: "personal/github.com.gpg", passphrase: "passforios")
        XCTAssertEqual(personal.plainText, "passwordforpersonal\n")

        let work = try decrypt(passwordStore: passwordStore, path: "work/github.com.gpg", passphrase: "passforios")
        XCTAssertEqual(work.plainText, "passwordforwork\n")

        let testPassword = Password(name: "test", url: URL(string: "test.gpg")!, plainText: "testpassword")
        let testPasswordEntity = try passwordStore.add(password: testPassword)!
        let testPasswordPlain = try passwordStore.decrypt(passwordEntity: testPasswordEntity, requestPGPKeyPassphrase: requestPGPKeyPassphrase)
        XCTAssertEqual(testPasswordPlain.plainText, "testpassword")

        passwordStore.erase()
    }

    private func decrypt(passwordStore: PasswordStore, path: String, passphrase _: String) throws -> Password {
        let entity = passwordStore.getPasswordEntity(by: path, isDir: false)!
        return try passwordStore.decrypt(passwordEntity: entity, requestPGPKeyPassphrase: requestPGPKeyPassphrase)
    }
}
