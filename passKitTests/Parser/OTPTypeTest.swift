//
//  OTPTypeTest.swift
//  passKitTests
//
//  Created by Danny Moesch on 01.12.18.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

import OneTimePassword
import XCTest

@testable import passKit

class OTPTypeTest: XCTestCase {

    func testInitFromToken() {
        let secret = "secret".data(using: .utf8)!

        let totpGenerator = Generator(factor: .timer(period: 30.0), secret: secret, algorithm: .sha1, digits: 6)!
        let totpToken = Token(name: "", issuer: "", generator: totpGenerator)
        XCTAssertEqual(OTPType(token: totpToken), .totp)

        let hotpGenerator = Generator(factor: .counter(4), secret: secret, algorithm: .sha1, digits: 6)!
        let hotpToken = Token(name: "", issuer: "", generator: hotpGenerator)
        XCTAssertEqual(OTPType(token: hotpToken), .hotp)

        XCTAssertEqual(OTPType(token: nil), .none)
    }

    func testInitFromString() {
        XCTAssertEqual(OTPType(name: "totp"), .totp)
        XCTAssertEqual(OTPType(name: "tOtP"), .totp)
        XCTAssertEqual(OTPType(name: "hotp"), .hotp)
        XCTAssertEqual(OTPType(name: "HoTp"), .hotp)
        XCTAssertEqual(OTPType(name: nil), .none)
        XCTAssertEqual(OTPType(name: ""), .none)
        XCTAssertEqual(OTPType(name: "something"), .none)
    }

    func testDescription() {
        XCTAssertEqual(OTPType(name: "totp").description, "TimeBased".localize())
        XCTAssertEqual(OTPType(name: "hotp").description, "HmacBased".localize())
        XCTAssertEqual(OTPType(name: nil).description, "None".localize())
    }
}
