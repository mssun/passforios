//
//  ConstantsTest.swift
//  passKitTests
//
//  Created by Danny Moesch on 30.09.18.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

import XCTest

@testable import passKit

class ConstantsTest: XCTestCase {
    func testIsOtpRelated() {
        XCTAssert(Constants.isOtpRelated(line: "otpauth://something"))
        XCTAssert(Constants.isOtpRelated(line: "otp_algorithm: algorithm"))
        XCTAssertFalse(Constants.isOtpRelated(line: "otp: something"))
        XCTAssertFalse(Constants.isOtpRelated(line: "otp"))
    }

    func testIsOtpKeyword() {
        XCTAssert(Constants.isOtpKeyword("otpauth"))
        XCTAssert(Constants.isOtpKeyword("oTP_DigITS"))
        XCTAssertFalse(Constants.isOtpKeyword("otp"))
        XCTAssertFalse(Constants.isOtpKeyword("no keyword"))
    }

    func testIsUnknown() {
        XCTAssert(Constants.isUnknown("unknown 1"))
        XCTAssert(Constants.isUnknown("unknown 435"))
        XCTAssertFalse(Constants.isUnknown("otp"))
        XCTAssertFalse(Constants.isUnknown("unknown "))
        XCTAssertFalse(Constants.isUnknown("unknown something"))
        XCTAssertFalse(Constants.isUnknown("unknown 123 something"))
        XCTAssertFalse(Constants.isUnknown("Unknown 1"))
    }

    func testUnknown() {
        XCTAssertEqual(Constants.unknown(0), "unknown 0")
        XCTAssertEqual(Constants.unknown(10), "unknown 10")
    }

    func testGetSeparator() {
        XCTAssertEqual(Constants.getSeparator(breakingLines: true), "\n")
        XCTAssertEqual(Constants.getSeparator(breakingLines: false), " ")
    }
}
