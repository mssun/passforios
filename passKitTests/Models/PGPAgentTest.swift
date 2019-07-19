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
    
    override func setUp() {
        PGPAgent().removePGPKeys()
    }
    
    override func tearDown() {
        PGPAgent().removePGPKeys()
    }
    
    func basicEncryptDecrypt(pgpAgent: PGPAgent) -> Bool {
        // Encrypt and decrypt.
        let plainData = "Hello World!".data(using: .utf8)!
        guard let encryptedData = try? pgpAgent.encrypt(plainData: plainData) else {
            return false
        }
        guard let decryptedData = try? pgpAgent.decrypt(encryptedData: encryptedData, requestPGPKeyPassphrase: requestPGPKeyPassphrase) else {
            return false
        }
        return plainData == decryptedData
    }
    
    func testInitPGPKey() {
        let pgpAgent = PGPAgent()

        // [RSA2048] Setup keys.
        try? pgpAgent.initPGPKey(with: PGP_RSA2048_PUBLIC_KEY, keyType: .PUBLIC)
        try? pgpAgent.initPGPKey(with: PGP_RSA2048_PRIVATE_KEY, keyType: .PRIVATE)
        XCTAssertTrue(pgpAgent.isImported)
        XCTAssertEqual(pgpAgent.pgpKeyID, "A1024DAE")
        XCTAssertTrue(self.basicEncryptDecrypt(pgpAgent: pgpAgent))
        let pgpAgent2 = PGPAgent()
        try? pgpAgent2.initPGPKeys()  // load from the keychain
        XCTAssertTrue(self.basicEncryptDecrypt(pgpAgent: pgpAgent2))
        pgpAgent.removePGPKeys()

        // [RSA2048] Setup keys. The private key is a subkey.
        try? pgpAgent.initPGPKey(with: PGP_RSA2048_PUBLIC_KEY, keyType: .PUBLIC)
        try? pgpAgent.initPGPKey(with: PGP_RSA2048_PRIVATE_SUBKEY, keyType: .PRIVATE)
        XCTAssertTrue(pgpAgent.isImported)
        XCTAssertEqual(pgpAgent.pgpKeyID, "A1024DAE")
        XCTAssertTrue(self.basicEncryptDecrypt(pgpAgent: pgpAgent))
        pgpAgent.removePGPKeys()

        // [ED25519] Setup keys.
        try? pgpAgent.initPGPKey(with: PGP_ED25519_PUBLIC_KEY, keyType: .PUBLIC)
        try? pgpAgent.initPGPKey(with: PGP_ED25519_PRIVATE_KEY, keyType: .PRIVATE)
        XCTAssertTrue(pgpAgent.isImported)
        XCTAssertEqual(pgpAgent.pgpKeyID, "E9444483")
        XCTAssertTrue(self.basicEncryptDecrypt(pgpAgent: pgpAgent))
        pgpAgent.removePGPKeys()
        
        // [RSA2048] Setup keys from URL.
        let publicKeyURL = URL(fileURLWithPath: PgpKey.PUBLIC.getFileSharingPath())
        let privateKeyURL = URL(fileURLWithPath: PgpKey.PRIVATE.getFileSharingPath())
        try? PGP_RSA2048_PUBLIC_KEY.write(to: publicKeyURL, atomically: false, encoding: .utf8)
        try? PGP_RSA2048_PRIVATE_KEY.write(to: privateKeyURL, atomically: false, encoding: .utf8)
        try? pgpAgent.initPGPKey(from: publicKeyURL, keyType: .PUBLIC)
        try? pgpAgent.initPGPKey(from: privateKeyURL, keyType: .PRIVATE)
        XCTAssertTrue(pgpAgent.isImported)
        XCTAssertEqual(pgpAgent.pgpKeyID, "A1024DAE")
        XCTAssertTrue(self.basicEncryptDecrypt(pgpAgent: pgpAgent))
        pgpAgent.removePGPKeys()
        
        // [RSA2048] Setup keys from iTunes file sharing.
        try? PGP_RSA2048_PUBLIC_KEY.write(to: publicKeyURL, atomically: false, encoding: .utf8)
        try? PGP_RSA2048_PRIVATE_KEY.write(to: privateKeyURL, atomically: false, encoding: .utf8)
        XCTAssertTrue(pgpAgent.isFileSharingReady)
        try? pgpAgent.initPGPKeyFromFileSharing()
        XCTAssertTrue(pgpAgent.isImported)
        XCTAssertEqual(pgpAgent.pgpKeyID, "A1024DAE")
        XCTAssertTrue(self.basicEncryptDecrypt(pgpAgent: pgpAgent))
        XCTAssertFalse(FileManager.default.fileExists(atPath: publicKeyURL.absoluteString))
        XCTAssertFalse(FileManager.default.fileExists(atPath: privateKeyURL.absoluteString))
        pgpAgent.removePGPKeys()
    }
    
    func testInitPGPKeyBadPrivateKeys() {
        let pgpAgent = PGPAgent()
        let plainData = "Hello World!".data(using: .utf8)!
        
        // [RSA2048] Setup the public key.
        try? pgpAgent.initPGPKey(with: PGP_RSA2048_PUBLIC_KEY, keyType: .PUBLIC)
        let encryptedData = try? pgpAgent.encrypt(plainData: plainData)
        XCTAssertNotNil(encryptedData)
        XCTAssertThrowsError(try pgpAgent.decrypt(encryptedData: encryptedData!, requestPGPKeyPassphrase: requestPGPKeyPassphrase))
        
        // Wrong private key: a public key.
        try? pgpAgent.initPGPKey(with: PGP_RSA2048_PUBLIC_KEY, keyType: .PRIVATE)
        XCTAssertThrowsError(try pgpAgent.decrypt(encryptedData: encryptedData!, requestPGPKeyPassphrase: requestPGPKeyPassphrase))
        
        // Wrong private key: an unmatched private key.
        try? pgpAgent.initPGPKey(with: PGP_ED25519_PRIVATE_KEY, keyType: .PRIVATE)
        XCTAssertThrowsError(try pgpAgent.decrypt(encryptedData: encryptedData!, requestPGPKeyPassphrase: requestPGPKeyPassphrase))
        
        /// Wrong private key: a corrupted private key.
        try? pgpAgent.initPGPKey(with: PGP_RSA2048_PRIVATE_KEY.replacingOccurrences(of: "1", with: ""), keyType: .PRIVATE)
        XCTAssertThrowsError(try pgpAgent.decrypt(encryptedData: encryptedData!, requestPGPKeyPassphrase: requestPGPKeyPassphrase))
    }
    
}

