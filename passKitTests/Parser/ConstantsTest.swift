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
        XCTAssertTrue(Constants.isOtpRelated(line: "otpauth://something"))
        XCTAssertTrue(Constants.isOtpRelated(line: "otp_algorithm: algorithm"))
        XCTAssertFalse(Constants.isOtpRelated(line: "otp: something"))
        XCTAssertFalse(Constants.isOtpRelated(line: "otp"))
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
