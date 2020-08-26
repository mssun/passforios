//
//  ScannableKeyTypeTest.swift
//  passTests
//
//  Created by Danny Moesch on 21.08.20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import XCTest

@testable import Pass

class ScannableKeyTypeTest: XCTestCase {
    func testPGPPublicKey() {
        let type = ScannableKeyType.pgpPublic

        XCTAssertEqual(type.visibility, "Public")
        XCTAssertEqual(type.headerStart, "-----BEGIN PGP PUBLIC KEY BLOCK-----")
        XCTAssertEqual(type.footerStart, "-----END PGP PUBLIC")
        XCTAssertEqual(type.footerEnd, "KEY BLOCK-----")
        XCTAssertEqual(type.counterType, .pgpPrivate)
    }

    func testPGPPrivateKey() {
        let type = ScannableKeyType.pgpPrivate

        XCTAssertEqual(type.visibility, "Private")
        XCTAssertEqual(type.headerStart, "-----BEGIN PGP PRIVATE KEY BLOCK-----")
        XCTAssertEqual(type.footerStart, "-----END PGP PRIVATE")
        XCTAssertEqual(type.footerEnd, "KEY BLOCK-----")
        XCTAssertEqual(type.counterType, .pgpPublic)
    }

    func testSSHPrivateKey() {
        let type = ScannableKeyType.sshPrivate

        XCTAssertEqual(type.visibility, "Private")
        XCTAssertEqual(type.headerStart, "-----BEGIN")
        XCTAssertEqual(type.footerStart, "-----END")
        XCTAssertEqual(type.footerEnd, "KEY-----")
        XCTAssertNil(type.counterType)
    }
}
