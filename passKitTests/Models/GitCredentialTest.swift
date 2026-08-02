//
//  GitCredentialTest.swift
//  passKitTests
//
//  Created by Danny Moesch on 29.08.20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import XCTest

import SwiftyUserDefaults
@testable import passKit

final class GitCredentialTest: XCTestCase {
    private static let defaultsID = "SharedDefaultsForGitCredentialTest"

    private let keyStore = DictBasedKeychain()

    override func setUp() {
        super.setUp()

        keyStore.add(string: "password", for: Globals.gitPassword)
        keyStore.add(string: "passphrase", for: Globals.gitSSHPrivateKeyPassphrase)

        UserDefaults().removePersistentDomain(forName: Self.defaultsID)
        passKit.Defaults = DefaultsAdapter(defaults: UserDefaults(suiteName: Self.defaultsID)!, keyStore: DefaultsKeys())
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: Self.defaultsID)

        super.tearDown()
    }

    func testDelete() {
        let password = GitCredential.from(authenticationMethod: .password, userName: "user", keyStore: keyStore)
        password.delete()
        XCTAssertFalse(keyStore.contains(key: Globals.gitPassword))
        XCTAssertTrue(keyStore.contains(key: Globals.gitSSHPrivateKeyPassphrase))

        let key = GitCredential.from(authenticationMethod: .key, userName: "user", keyStore: keyStore)
        key.delete()
        XCTAssertFalse(keyStore.contains(key: Globals.gitPassword))
        XCTAssertFalse(keyStore.contains(key: Globals.gitSSHPrivateKeyPassphrase))
    }

    func testOptions() {
        let password = GitCredential.from(authenticationMethod: .password, userName: "user", keyStore: keyStore)

        let provider = password.getCredentialOptions().credentialProvider
        XCTAssertNotNil(provider)
        XCTAssertEqual(provider?.userName, "user")
    }

    func testEmptyOptions() {
        XCTAssertNil(GitCredentialOptions().credentialProvider)
    }

    func testPasswordCredentialSpec() {
        let credentialProvider = getCredentialProvider(authenticationMethod: .password)

        guard case let .userPassPlaintext(userName, password) = credentialProvider.nextCredential() else {
            XCTFail("Expected a plaintext user name and password.")
            return
        }
        XCTAssertEqual(userName, "user")
        XCTAssertEqual(password, "password")
    }

    func testSSHKeyCredentialSpec() {
        keyStore.add(string: "private key", for: SSHKey.PRIVATE.getKeychainKey())
        let credentialProvider = getCredentialProvider(authenticationMethod: .key)

        guard case let .sshKeyMemory(userName, publicKey, privateKey, passphrase) = credentialProvider.nextCredential() else {
            XCTFail("Expected an in-memory SSH key.")
            return
        }
        XCTAssertEqual(userName, "user")
        XCTAssertNil(publicKey)
        XCTAssertEqual(privateKey, "private key")
        XCTAssertEqual(passphrase, "passphrase")
    }

    func testPasswordCredentialProvider() {
        let password = GitCredential.from(authenticationMethod: .password, userName: "user", keyStore: keyStore)
        let expectation = expectation(description: "Password is requested.")
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = 3
        let credentialProvider = password.createCredentialProvider { _, _ in
            expectation.fulfill()
            return "otherPassword"
        }

        (1 ..< 5).forEach { _ in
            XCTAssertNotNil(credentialProvider.nextCredential())
        }
        XCTAssertNil(credentialProvider.nextCredential())
        wait(for: [expectation], timeout: 0)
    }

    func testSSHKeyCredentialProvider() {
        let credentialProvider = getCredentialProvider(authenticationMethod: .key)

        XCTAssertNotNil(credentialProvider.nextCredential())
        XCTAssertNil(credentialProvider.nextCredential())
    }

    func testCannotGetPassword() {
        let credentialProvider = getCredentialProvider(authenticationMethod: .password)

        XCTAssertNotNil(credentialProvider.nextCredential())
        XCTAssertNil(credentialProvider.nextCredential())
    }

    func testSaveToKeyStore() {
        let credentialProvider = getCredentialProvider(authenticationMethod: .key, password: "otherPassword")

        passKit.Defaults.isRememberGitCredentialPassphraseOn = true
        keyStore.removeAllContent()
        _ = credentialProvider.nextCredential()

        XCTAssertEqual(keyStore.get(for: Globals.gitSSHPrivateKeyPassphrase), "otherPassword")
    }

    private func getCredentialProvider(authenticationMethod: GitAuthenticationMethod, password: String? = nil) -> GitCredentialProvider {
        let credential = GitCredential.from(authenticationMethod: authenticationMethod, userName: "user", keyStore: keyStore)
        return credential.createCredentialProvider { _, _ in password }
    }
}
