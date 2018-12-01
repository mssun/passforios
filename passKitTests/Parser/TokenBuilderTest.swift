//
//  TokenBuilderTest.swift
//  passKitTests
//
//  Created by Danny Moesch on 01.12.18.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

import Base32
import OneTimePassword
import XCTest

@testable import passKit

class TokenBuilderTest: XCTestCase {

    private let SECRET = "secret"
    private let DIGITS = Constants.DEFAULT_DIGITS
    private let TIMER = Generator.Factor.timer(period: Constants.DEFAULT_PERIOD)

    func testNoSecret() {
        XCTAssertNil(TokenBuilder().build())
        XCTAssertNil(TokenBuilder().usingSecret(nil).build())
        XCTAssertNil(TokenBuilder().usingSecret("").build())
    }

    func testDefault() {
        let token = TokenBuilder()
            .usingSecret(SECRET)
            .build()

        XCTAssertEqual(token?.generator.secret, MF_Base32Codec.data(fromBase32String: SECRET))
        XCTAssertEqual(token?.generator.factor, TIMER)
        XCTAssertEqual(token?.generator.algorithm, .sha1)
        XCTAssertEqual(token?.generator.digits, DIGITS)
    }

    func testName() {
        [
            "some name",
            "a",
            "totp",
        ].forEach { name in
            let token = TokenBuilder()
                .usingName(name)
                .usingSecret(SECRET)
                .build()

            XCTAssertEqual(token?.name, name)
        }
    }

    func testTypeNone() {
        let token = TokenBuilder()
            .usingSecret(SECRET)
            .usingType("something")
            .build()

        XCTAssertNil(token)
    }

    func testTypeTotp() {
        let token = TokenBuilder()
            .usingSecret(SECRET)
            .usingType("toTp")
            .build()

        XCTAssertEqual(token?.generator.factor, TIMER)
    }

    func testTypeHotp() {
        let token = TokenBuilder()
            .usingSecret(SECRET)
            .usingType("HotP")
            .usingCounter("4")
            .build()

        XCTAssertEqual(token?.generator.factor, Generator.Factor.counter(4))
    }

    func testAlgorithm() {
        [
            ("sha1", .sha1),
            ("something", .sha1),
            (nil, .sha1),
            ("sha256", .sha256),
            ("Sha256", .sha256),
            ("sha512", .sha512),
            ("sHA512", .sha512),
        ].forEach { (inputAlgorithm: String?, algorithm: Generator.Algorithm) in
            let token = TokenBuilder()
                .usingSecret(SECRET)
                .usingAlgorithm(inputAlgorithm)
                .build()

            XCTAssertEqual(token?.generator.algorithm, algorithm)
        }
    }

    func testDigits() {
        [
            (nil, nil),
            (5, nil),
            (6, 6),
            (7, 7),
            (8, 8),
            (9, nil),
        ].forEach { inputDigits, digits in
            let token = TokenBuilder()
                .usingSecret(SECRET)
                .usingDigits(inputDigits == nil ? nil : String(inputDigits!))
                .build()

            XCTAssertEqual(token?.generator.digits, digits)
        }
    }

    func testUnparsableDigits() {
        let token = TokenBuilder()
            .usingSecret(SECRET)
            .usingDigits("unparsable digits")
            .build()

        XCTAssertNil(token)
    }

    func testPeriod() {
        [
            (nil, nil),
            (1.2, 1.2),
            (-12.0, nil),
            (27.5, 27.5),
            (35.0, 35.0),
            (120.7, 120.7),
        ].forEach { inputPeriod, period in
            let token = TokenBuilder()
                .usingSecret(SECRET)
                .usingPeriod(inputPeriod == nil ? nil : String(inputPeriod!))
                .build()
            let timer = period == nil ? nil : Generator.Factor.timer(period: period!)

            XCTAssertEqual(token?.generator.factor, timer)
        }
    }

    func testUnparsablePeriod() {
        let token = TokenBuilder()
            .usingSecret(SECRET)
            .usingPeriod("unparsable period")
            .build()

        XCTAssertNil(token)
    }

    func testCounter() {
        [
            (nil, nil),
            (1, 1),
            (0, 0),
            (27, 27),
            (120, 120),
            (4321, 4321),
        ].forEach { inputCounter, counter in
            let token = TokenBuilder()
                .usingSecret(SECRET)
                .usingType("hotp")
                .usingCounter(inputCounter == nil ? nil : String(inputCounter!))
                .build()
            let counter = counter == nil ? nil : Generator.Factor.counter(UInt64(counter!))

            XCTAssertEqual(token?.generator.factor, counter)
        }
    }

    func testUnparsableCounter() {
        let token = TokenBuilder()
            .usingSecret(SECRET)
            .usingType("hotp")
            .usingCounter("unparsable counter")
            .build()

        XCTAssertNil(token)
    }

    func testAllMixed() {
        let builder = TokenBuilder()
            .usingName("name")
            .usingSecret(SECRET)
            .usingAlgorithm("sha512")
            .usingDigits("7")
            .usingPeriod("42")
            .usingCounter("12")

        let totpToken = builder.usingType("totp").build()

        XCTAssertNotNil(totpToken)
        XCTAssertEqual(totpToken?.name, "name")
        XCTAssertEqual(totpToken?.currentPassword?.count, 7)
        XCTAssertEqual(totpToken?.generator.algorithm, .sha512)
        XCTAssertEqual(totpToken?.generator.digits, 7)
        XCTAssertEqual(totpToken?.generator.factor, .timer(period: 42))
        XCTAssertEqual(totpToken?.generator.secret, MF_Base32Codec.data(fromBase32String: SECRET))

        let hotpToken = builder.usingType("hotp").build()

        XCTAssertNotNil(hotpToken)
        XCTAssertEqual(hotpToken?.name, "name")
        XCTAssertEqual(hotpToken?.currentPassword?.count, 7)
        XCTAssertEqual(hotpToken?.generator.algorithm, .sha512)
        XCTAssertEqual(hotpToken?.generator.digits, 7)
        XCTAssertEqual(hotpToken?.generator.factor, .counter(12))
        XCTAssertEqual(hotpToken?.generator.secret, MF_Base32Codec.data(fromBase32String: SECRET))
    }
}
