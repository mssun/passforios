//
//  PGPAgentTest.swift
//  passKitTests
//
//  Created by Yishi Lin on 2019/7/17.
//  Copyright © 2019 Bob Sun. All rights reserved.
//

import SwiftyUserDefaults
import XCTest

@testable import passKit

class PGPAgentTest: XCTestCase {
    private var keychain: KeyStore!
    private var pgpAgent: PGPAgent!

    private let testData = "Hello World!".data(using: .utf8)!

    override func setUp() {
        super.setUp()
        keychain = DictBasedKeychain()
        pgpAgent = PGPAgent(keyStore: keychain)
        UserDefaults().removePersistentDomain(forName: "SharedDefaultsForPGPAgentTest")
        passKit.Defaults = DefaultsAdapter(defaults: UserDefaults(suiteName: "SharedDefaultsForPGPAgentTest")!, keyStore: DefaultsKeys())
    }

    override func tearDown() {
        keychain.removeAllContent()
        UserDefaults().removePersistentDomain(forName: "SharedDefaultsForPGPAgentTest")
        super.tearDown()
    }

    private func basicEncryptDecrypt(using pgpAgent: PGPAgent, keyID: String, encryptKeyID: String? = nil, requestPassphrase: @escaping (String) -> String = requestPGPKeyPassphrase, encryptInArmored: Bool = true, decryptFromArmored: Bool = true) throws -> Data? {
        passKit.Defaults.encryptInArmored = encryptInArmored
        let encryptedData = try pgpAgent.encrypt(plainData: testData, keyID: keyID)
        passKit.Defaults.encryptInArmored = decryptFromArmored
        return try pgpAgent.decrypt(encryptedData: encryptedData, keyID: encryptKeyID ?? keyID, requestPGPKeyPassphrase: requestPassphrase)
    }

    func testMultiKeys() throws {
        try [
            RSA2048_RSA4096,
            ED25519_NISTP384,
        ].forEach { testKeyInfo in
            keychain.removeAllContent()
            try importKeys(testKeyInfo.publicKeys, testKeyInfo.privateKeys)
            XCTAssert(pgpAgent.isPrepared)
            try pgpAgent.initKeys()
            try [
                (true, true),
                (true, false),
                (false, true),
                (false, false),
            ].forEach { encryptInArmored, decryptFromArmored in
                for id in testKeyInfo.fingerprints {
                    XCTAssertEqual(try basicEncryptDecrypt(using: pgpAgent, keyID: id, encryptInArmored: encryptInArmored, decryptFromArmored: decryptFromArmored), testData)
                }
            }
        }
    }

    func testBasicEncryptDecrypt() throws {
        try [
            RSA2048,
            RSA2048_SUB,
            RSA3072_NO_PASSPHRASE,
            RSA4096,
            RSA4096_SUB,
            ED25519,
            ED25519_SUB,
            NISTP384,
        ].forEach { testKeyInfo in
            keychain.removeAllContent()
            try importKeys(testKeyInfo.publicKey, testKeyInfo.privateKey)
            XCTAssert(pgpAgent.isPrepared)
            try pgpAgent.initKeys()
            XCTAssert(try pgpAgent.getKeyID().first!.lowercased().hasSuffix(testKeyInfo.fingerprint))
            try [
                (true, true),
                (true, false),
                (false, true),
                (false, false),
            ].forEach { encryptInArmored, decryptFromArmored in
                XCTAssertEqual(try basicEncryptDecrypt(using: pgpAgent, keyID: testKeyInfo.fingerprint, encryptInArmored: encryptInArmored, decryptFromArmored: decryptFromArmored), testData)
            }
        }
    }

    func testNoPrivateKey() throws {
        try KeyFileManager(keyType: PGPKey.PUBLIC, keyPath: "", keyHandler: keychain.add).importKey(from: RSA2048.publicKey)
        XCTAssertFalse(pgpAgent.isPrepared)
        XCTAssertThrowsError(try pgpAgent.initKeys()) {
            XCTAssertEqual($0 as! AppError, AppError.keyImport)
        }
        XCTAssertThrowsError(try basicEncryptDecrypt(using: pgpAgent, keyID: RSA2048.fingerprint)) {
            XCTAssertEqual($0 as! AppError, AppError.keyImport)
        }
    }

    func testInterchangePublicAndPrivateKey() throws {
        try importKeys(RSA2048.privateKey, RSA2048.publicKey)
        XCTAssert(pgpAgent.isPrepared)
        XCTAssertThrowsError(try basicEncryptDecrypt(using: pgpAgent, keyID: RSA2048.fingerprint)) {
            XCTAssert($0.localizedDescription.contains("gopenpgp: unable to add locked key to a keyring"))
        }
    }

    func testIncompatibleKeyTypes() throws {
        try importKeys(ED25519.publicKey, RSA2048.privateKey)
        XCTAssert(pgpAgent.isPrepared)
        XCTAssertThrowsError(try basicEncryptDecrypt(using: pgpAgent, keyID: ED25519.fingerprint, encryptKeyID: RSA2048.fingerprint)) {
            XCTAssertEqual($0 as! AppError, AppError.keyExpiredOrIncompatible)
        }
    }

    func testCorruptedKey() throws {
        try importKeys(RSA2048.publicKey.replacingOccurrences(of: "1", with: ""), RSA2048.privateKey)
        XCTAssert(pgpAgent.isPrepared)
        XCTAssertThrowsError(try basicEncryptDecrypt(using: pgpAgent, keyID: RSA2048.fingerprint)) {
            XCTAssert($0.localizedDescription.contains("Can't read keys. Invalid input."))
        }
    }

    func testUnsetKeys() throws {
        try importKeys(ED25519.publicKey, ED25519.privateKey)
        XCTAssert(pgpAgent.isPrepared)
        XCTAssertEqual(try basicEncryptDecrypt(using: pgpAgent, keyID: ED25519.fingerprint), testData)
        keychain.removeContent(for: PGPKey.PUBLIC.getKeychainKey())
        keychain.removeContent(for: PGPKey.PRIVATE.getKeychainKey())
        XCTAssertThrowsError(try basicEncryptDecrypt(using: pgpAgent, keyID: ED25519.fingerprint)) {
            XCTAssertEqual($0 as! AppError, AppError.keyImport)
        }
    }

    func testNoDecryptionWithIncorrectPassphrase() throws {
        try importKeys(RSA2048.publicKey, RSA2048.privateKey)

        var passphraseRequestCalledCount = 0
        let provideCorrectPassphrase: (String) -> String = { _ in
            passphraseRequestCalledCount += 1
            return requestPGPKeyPassphrase(keyID: RSA2048.fingerprint)
        }
        let provideIncorrectPassphrase: (String) -> String = { _ in
            passphraseRequestCalledCount += 1
            return "incorrect passphrase"
        }

        // Provide the correct passphrase.
        XCTAssertEqual(try basicEncryptDecrypt(using: pgpAgent, keyID: RSA2048.fingerprint, requestPassphrase: provideCorrectPassphrase), testData)
        XCTAssertEqual(passphraseRequestCalledCount, 1)

        // Provide the wrong passphrase.
        XCTAssertThrowsError(try basicEncryptDecrypt(using: pgpAgent, keyID: RSA2048.fingerprint, requestPassphrase: provideIncorrectPassphrase)) {
            XCTAssertEqual($0 as! AppError, AppError.wrongPassphrase)
        }
        XCTAssertEqual(passphraseRequestCalledCount, 2)

        // Ask for the passphrase because the previous decryption has failed.
        XCTAssertEqual(try basicEncryptDecrypt(using: pgpAgent, keyID: RSA2048.fingerprint, requestPassphrase: provideCorrectPassphrase), testData)
        XCTAssertEqual(passphraseRequestCalledCount, 3)
    }

    private func importKeys(_ publicKey: String, _ privateKey: String) throws {
        try KeyFileManager(keyType: PGPKey.PUBLIC, keyPath: "", keyHandler: keychain.add).importKey(from: publicKey)
        try KeyFileManager(keyType: PGPKey.PRIVATE, keyPath: "", keyHandler: keychain.add).importKey(from: privateKey)
    }
}
