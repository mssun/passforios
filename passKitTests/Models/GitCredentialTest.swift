//
//  GitCredentialTest.swift
//  passKitTests
//
//  Created by Danny Moesch on 29.08.20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import XCTest

import ObjectiveGit
import SwiftyUserDefaults
@testable import passKit

class GitCredentialTest: XCTestCase {
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

        let options = password.getCredentialOptions()
        XCTAssertEqual(options.count, 2)

        let cloneCredentialProvider = options[GTRepositoryCloneOptionsCredentialProvider] as! GTCredentialProvider
        let remoteCredentialProvider = options[GTRepositoryRemoteOptionsCredentialProvider] as! GTCredentialProvider
        XCTAssertNotNil(cloneCredentialProvider)
        XCTAssertEqual(cloneCredentialProvider, remoteCredentialProvider)
    }

    func testPasswordCredentialProvider() {
        let password = GitCredential.from(authenticationMethod: .password, userName: "user", keyStore: keyStore)
        let expectation = self.expectation(description: "Password is requested.")
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = 3
        let options = password.getCredentialOptions { _, _ in
            expectation.fulfill()
            return "otherPassword"
        }
        let credentialProvider = options[GTRepositoryCloneOptionsCredentialProvider] as! GTCredentialProvider

        (1 ..< 5).forEach { _ in
            XCTAssertNotNil(credentialProvider.credential(for: .userPassPlaintext, url: nil, userName: nil))
        }
        XCTAssertNil(credentialProvider.credential(for: .userPassPlaintext, url: nil, userName: nil))
        wait(for: [expectation], timeout: 0)
    }

    func testSSHKeyCredentialProvider() {
        let credentialProvider = getCredentialProvider(authenticationMethod: .key)

        XCTAssertNotNil(credentialProvider.credential(for: .sshCustom, url: nil, userName: nil))
        XCTAssertNil(credentialProvider.credential(for: .sshCustom, url: nil, userName: nil))
    }

    func testCannotGetPassword() {
        let credentialProvider = getCredentialProvider(authenticationMethod: .password)

        XCTAssertNotNil(credentialProvider.credential(for: .userPassPlaintext, url: nil, userName: nil))
        XCTAssertNil(credentialProvider.credential(for: .userPassPlaintext, url: nil, userName: nil))
    }

    func testSaveToKeyStore() {
        let credentialProvider = getCredentialProvider(authenticationMethod: .key, password: "otherPassword")

        passKit.Defaults.isRememberGitCredentialPassphraseOn = true
        keyStore.removeAllContent()
        credentialProvider.credential(for: .sshCustom, url: nil, userName: nil)

        XCTAssertEqual(keyStore.get(for: Globals.gitSSHPrivateKeyPassphrase), "otherPassword")
    }

    private func getCredentialProvider(authenticationMethod: GitAuthenticationMethod, password: String? = nil) -> GTCredentialProvider {
        let credential = GitCredential.from(authenticationMethod: authenticationMethod, userName: "user", keyStore: keyStore)
        let options = credential.getCredentialOptions { _, _ in password }
        return options[GTRepositoryCloneOptionsCredentialProvider] as! GTCredentialProvider
    }
}
