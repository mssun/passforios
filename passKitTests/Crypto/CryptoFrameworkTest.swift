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
            RSA4096,
            //RSA2048_SUB,
            ED25519,
            //ED25519_SUB,
        ].forEach { keyTriple in
            var error: NSError?
            guard let publicKey = CryptoNewKeyFromArmored(keyTriple.publicKey, &error),
                  let privateKey = CryptoNewKeyFromArmored(keyTriple.privateKey, &error) else {
                XCTFail("Keys cannot be initialized.")
                return
            }
            XCTAssertNil(error)

            XCTAssert(publicKey.getHexKeyID().hasSuffix(keyTriple.fingerprint))
            XCTAssertNil(error)

            let unlockedKey = try privateKey.unlock(keyTriple.passphrase.data(using: .utf8))
            let encryptedMessage = try CryptoNewKeyRing(publicKey, &error)?.encrypt(plainMessage, privateKey: nil)
            let decryptedData = try CryptoNewKeyRing(unlockedKey, &error)?.decrypt(messageConverter(encryptedMessage!, &error), verifyKey: nil, verifyTime: 0)
            XCTAssertNil(error)
            XCTAssertEqual(testText, decryptedData!.getString())
        }
    }
}
