//
//  PGPAgent.swift
//  passKitTests
//
//  Created by Yishi Lin on 2019/7/17.
//  Copyright © 2019 Bob Sun. All rights reserved.
//

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
    }

    override func tearDown() {
        keychain.removeAllContent()
        super.tearDown()
    }

    func basicEncryptDecrypt(using pgpAgent: PGPAgent, requestPassphrase: () -> String = requestPGPKeyPassphrase) throws -> Data? {
        let encryptedData = try pgpAgent.encrypt(plainData: testData)
        return try pgpAgent.decrypt(encryptedData: encryptedData, requestPGPKeyPassphrase: requestPassphrase)
    }

    func testBasicEncryptDecrypt() throws {
        try [
            RSA2048,
            RSA2048_SUB,
            ED25519,
            //ED25519_SUB,
        ].forEach { keyTriple in
            let keychain = DictBasedKeychain()
            let pgpAgent = PGPAgent(keyStore: keychain)
            try KeyFileManager(keyType: PgpKey.PUBLIC, keyPath: "", keyHandler: keychain.add).importKey(from: keyTriple.publicKey)
            try KeyFileManager(keyType: PgpKey.PRIVATE, keyPath: "", keyHandler: keychain.add).importKey(from: keyTriple.privateKey)
            XCTAssert(pgpAgent.isPrepared)
            try pgpAgent.initKeys()
            XCTAssert(pgpAgent.keyId!.lowercased().hasSuffix(keyTriple.fingerprint))
            XCTAssertEqual(try basicEncryptDecrypt(using: pgpAgent), testData)
        }
    }

    func testNoPrivateKey() throws {
        try KeyFileManager(keyType: PgpKey.PUBLIC, keyPath: "", keyHandler: keychain.add).importKey(from: RSA2048.publicKey)
        XCTAssertFalse(pgpAgent.isPrepared)
        XCTAssertThrowsError(try pgpAgent.initKeys()) {
            XCTAssertEqual($0 as! AppError, AppError.KeyImport)
        }
        XCTAssertThrowsError(try basicEncryptDecrypt(using: pgpAgent)) {
            XCTAssertEqual($0 as! AppError, AppError.KeyImport)
        }
    }

    func testInterchangePublicAndPrivateKey() throws {
        try importKeys(RSA2048.privateKey, RSA2048.publicKey)
        XCTAssert(pgpAgent.isPrepared)
        XCTAssertThrowsError(try basicEncryptDecrypt(using: pgpAgent)) {
            XCTAssert($0.localizedDescription.contains("gopenpgp: cannot unlock key ring, no private key available"))
        }
    }

    func testIncompatibleKeyTypes() throws {
        try importKeys(ED25519.publicKey, RSA2048.privateKey)
        XCTAssert(pgpAgent.isPrepared)
        XCTAssertThrowsError(try basicEncryptDecrypt(using: pgpAgent)) {
            XCTAssert($0.localizedDescription.contains("openpgp: incorrect key"))
        }
    }

    func testCorruptedKey() throws {
        try importKeys(RSA2048.publicKey.replacingOccurrences(of: "1", with: ""), RSA2048.privateKey)
        XCTAssert(pgpAgent.isPrepared)
        XCTAssertThrowsError(try basicEncryptDecrypt(using: pgpAgent)) {
            XCTAssert($0.localizedDescription.contains("Can't read keys. Invalid input."))
        }
    }

    func testUnsettKeys() throws {
        try importKeys(ED25519.publicKey, ED25519.privateKey)
        XCTAssert(pgpAgent.isPrepared)
        XCTAssertEqual(try basicEncryptDecrypt(using: pgpAgent), testData)
        keychain.removeContent(for: PgpKey.PUBLIC.getKeychainKey())
        keychain.removeContent(for: PgpKey.PRIVATE.getKeychainKey())
        XCTAssertThrowsError(try basicEncryptDecrypt(using: pgpAgent)) {
            XCTAssertEqual($0 as! AppError, AppError.KeyImport)
        }
    }

    func testNoDecryptionWithIncorrectPassphrase() throws {
        try importKeys(RSA2048.publicKey, RSA2048.privateKey)

        var passphraseRequestCalled = false
        let provideCorrectPassphrase: () -> String = {
            passphraseRequestCalled = true
            return requestPGPKeyPassphrase()
        }
        XCTAssertEqual(try basicEncryptDecrypt(using: pgpAgent, requestPassphrase: provideCorrectPassphrase), testData)
        XCTAssert(passphraseRequestCalled)

        passphraseRequestCalled = false
        let provideIncorrectPassphrase: () -> String = {
            passphraseRequestCalled = true
            return "incorrect passphrase"
        }
        XCTAssertThrowsError(try basicEncryptDecrypt(using: pgpAgent, requestPassphrase: provideIncorrectPassphrase)) {
            XCTAssert($0.localizedDescription.contains("openpgp: invalid data: private key checksum failure"))
        }
        XCTAssert(passphraseRequestCalled)
    }

    private func importKeys(_ publicKey: String, _ privateKey: String) throws {
        try KeyFileManager(keyType: PgpKey.PUBLIC, keyPath: "", keyHandler: keychain.add).importKey(from: publicKey)
        try KeyFileManager(keyType: PgpKey.PRIVATE, keyPath: "", keyHandler: keychain.add).importKey(from: privateKey)
    }
}

