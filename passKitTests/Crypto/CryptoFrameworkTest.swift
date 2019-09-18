//
//  CryptoFrameworkTest.swift
//  passKitTests
//
//  Created by Danny Moesch on 22.08.19.
//  Copyright © 2019 Bob Sun. All rights reserved.
//

import XCTest

@testable import passKit
@testable import Crypto

class CryptoFrameworkTest: XCTestCase {

    typealias MessageConverter = (CryptoPGPMessage, NSErrorPointer) -> CryptoPGPMessage?

    private let testText = "Hello World!"

    func testArmoredEncryptDecrypt() throws {
        let plainMessage = CryptoNewPlainMessageFromString(testText)
        let messageConverter: MessageConverter = { encryptedMessage, error in
            CryptoNewPGPMessageFromArmored(encryptedMessage.getArmored(error), error)
        }

        try testInternal(plainMessage: plainMessage, messageConverter: messageConverter)
    }

    func testDataBasedEncryptDecrypt() throws {
        let plainMessage = CryptoNewPlainMessage(testText.data(using: .utf8)!.mutable as Data)
        let messageConverter: MessageConverter = { encryptedMessage, _ in
            CryptoNewPGPMessage(encryptedMessage.getBinary()!.mutable as Data)
        }

        try testInternal(plainMessage: plainMessage, messageConverter: messageConverter)
    }

    private func testInternal(plainMessage: CryptoPlainMessage?, messageConverter: MessageConverter) throws {
        try [
            RSA2048,
            RSA2048_SUB,
            ED25519,
            ED25519_SUB,
        ].forEach { keyTriple in
            let pgp = CryptoGetGopenPGP()!
            let publicKey = try pgp.buildKeyRingArmored(keyTriple.publicKey)
            let privateKey = try pgp.buildKeyRingArmored(keyTriple.privateKey)
            var error: NSError?

            XCTAssert(publicKey.getFingerprint(&error).hasSuffix(keyTriple.fingerprint))
            XCTAssertNil(error)

            try privateKey.unlock(withPassphrase: keyTriple.passphrase)
            let encryptedMessage = try publicKey.encrypt(plainMessage, privateKey: nil)
            let decryptedData = try privateKey.decrypt(messageConverter(encryptedMessage, &error), verifyKey: nil, verifyTime: 0)
            XCTAssertNil(error)
            XCTAssertEqual(testText, decryptedData.getString())
        }
    }
}
