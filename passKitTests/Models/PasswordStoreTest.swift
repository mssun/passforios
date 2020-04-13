//
//  PasswordStoreTest.swift
//  passKitTests
//
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import Foundation
import XCTest
import ObjectiveGit

@testable import passKit

class PasswordStoreTest: XCTestCase {
    let cloneOptions: [String : GTCredentialProvider] = {
           let credentialProvider = GTCredentialProvider { (_, _, _) -> (GTCredential?) in
               try? GTCredential(userName: "", password: "")
           }
           return [GTRepositoryCloneOptionsCredentialProvider: credentialProvider]
       }()
    let remoteRepoURL = URL(string: "https://github.com/mssun/passforios-password-store.git")!


    func testCloneAndDecryptMultiKeys() throws {
        let url = URL(fileURLWithPath: "\(Globals.repositoryPath)-test")
        let passwordStore = PasswordStore(url: url)
        let expectation = self.expectation(description: "clone")
        try passwordStore.cloneRepository(
            remoteRepoURL: remoteRepoURL,
            options: cloneOptions,
            branchName: "master",
            transferProgressBlock: { _, _ in },
            checkoutProgressBlock: { _, _, _ in }
        ) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 3, handler: nil)

        [
            ("work/github.com", "4712286271220DB299883EA7062E678DA1024DAE"),
            ("personal/github.com", "787EAE1A5FA3E749AA34CC6AA0645EBED862027E")
        ].forEach {(path, id) in
            let keyID = findGPGID(from: url.appendingPathComponent(path))
            XCTAssertEqual(keyID, id)
        }

        let keychain = AppKeychain.shared
        try KeyFileManager(keyType: PgpKey.PUBLIC, keyPath: "", keyHandler: keychain.add).importKey(from: RSA2048_RSA4096.publicKey)
        try KeyFileManager(keyType: PgpKey.PRIVATE, keyPath: "", keyHandler: keychain.add).importKey(from: RSA2048_RSA4096.privateKey)
        try PGPAgent.shared.initKeys()

        let personal = try decrypt(passwordStore: passwordStore, path: "personal/github.com.gpg", passphrase: "passforios")
        XCTAssertEqual(personal.plainText, "passwordforpersonal\n")

        let work = try decrypt(passwordStore: passwordStore, path: "work/github.com.gpg", passphrase: "passforios")
        XCTAssertEqual(work.plainText, "passwordforwork\n")

        passwordStore.erase()
    }

    private func decrypt(passwordStore: PasswordStore, path: String, passphrase: String) throws -> Password {
        let entity = passwordStore.getPasswordEntity(by: path, isDir: false)!
        return try passwordStore.decrypt(passwordEntity: entity, requestPGPKeyPassphrase: { passphrase } )!

    }

}

