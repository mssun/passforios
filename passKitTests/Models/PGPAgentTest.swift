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
        print("setup")
        AppKeychain.removeAllContent()
    }
    
    override func tearDown() {
        print("tearDown")
        AppKeychain.removeAllContent()
    }
    
    func encrypt_decrypt(pgpAgent: PGPAgent) {
        // Encrypt and decrypt.
        let plainData = "Hello World!".data(using: .utf8)!
        let encryptedData = try? pgpAgent.encrypt(plainData: plainData)
        XCTAssertNotNil(encryptedData)
        let decryptedData = try? pgpAgent.decrypt(encryptedData: encryptedData!, requestPGPKeyPassphrase: requestPGPKeyPassphrase)
        XCTAssertEqual(plainData, decryptedData)
    }
    
    func testInitPGPKey() {
        let pgpAgent = PGPAgent()
        
        // [RSA2048] Setup keys.
        try? pgpAgent.initPGPKey(with: PGP_RSA2048_PUBLIC_KEY, keyType: .PUBLIC)
        try? pgpAgent.initPGPKey(with: PGP_RSA2048_PRIVATE_KEY, keyType: .PRIVATE)
        XCTAssertTrue(pgpAgent.imported)
        XCTAssertEqual(pgpAgent.pgpKeyID, "A1024DAE")
        self.encrypt_decrypt(pgpAgent: pgpAgent)
        let pgpAgent2 = PGPAgent()
        try? pgpAgent2.initPGPKeys()  // load from the keychain
        self.encrypt_decrypt(pgpAgent: pgpAgent2)
        
        // [RSA2048] Setup keys. The private key is a subkey.
        try? pgpAgent.initPGPKey(with: PGP_RSA2048_PUBLIC_KEY, keyType: .PUBLIC)
        try? pgpAgent.initPGPKey(with: PGP_RSA2048_PRIVATE_SUBKEY, keyType: .PRIVATE)
        XCTAssertTrue(pgpAgent.imported)
        XCTAssertEqual(pgpAgent.pgpKeyID, "A1024DAE")
        self.encrypt_decrypt(pgpAgent: pgpAgent)
        
        // [ED25519] Setup keys.
        try? pgpAgent.initPGPKey(with: PGP_ED25519_PUBLIC_KEY, keyType: .PUBLIC)
        try? pgpAgent.initPGPKey(with: PGP_ED25519_PRIVATE_KEY, keyType: .PRIVATE)
        XCTAssertTrue(pgpAgent.imported)
        XCTAssertEqual(pgpAgent.pgpKeyID, "E9444483")
        self.encrypt_decrypt(pgpAgent: pgpAgent)
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

