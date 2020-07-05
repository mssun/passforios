//
//  PasswordGeneratorTest.swift
//  passKitTests
//
//  Created by Danny Moesch on 26.02.20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import XCTest

@testable import passKit

class PasswordGeneratorTest: XCTestCase {
    func testLimitedLength() {
        [
            PasswordGenerator(length: 15),
            PasswordGenerator(length: -3),
            PasswordGenerator(length: 128),
        ].forEach { generator in
            XCTAssertLessThanOrEqual(generator.limitedLength, generator.flavor.lengthLimits.max)
            XCTAssertGreaterThanOrEqual(generator.limitedLength, generator.flavor.lengthLimits.min)
        }
    }

    func testAcceptableGroups() {
        [
            (15, 4),
            (19, 4),
            (9, 5),
            (11, 6),
            (259, 13),
        ].forEach { length, groups in
            XCTAssertTrue(PasswordGenerator(length: length).isAcceptable(groups: groups))
        }
    }

    func testNotAcceptableGroups() {
        [
            (15, 0),
            (19, 20),
            (9, 9),
            (11, -1),
        ].forEach { length, groups in
            XCTAssertFalse(PasswordGenerator(length: length).isAcceptable(groups: groups))
        }
    }

    func testGroupsAreNotAcceptableForXKCDStyle() {
        var generator = PasswordGenerator(length: 15)

        XCTAssertTrue(generator.isAcceptable(groups: 4))

        generator.flavor = .xkcd
        XCTAssertFalse(generator.isAcceptable(groups: 4))
    }

    func testRandomGroupsCount() {
        [
            PasswordGenerator(length: 15, groups: 4),
            PasswordGenerator(length: 24, groups: 5),
            PasswordGenerator(length: 63, groups: 8),
        ].forEach { generator in
            XCTAssertEqual(generator.generate().split(separator: "-").count, generator.groups)
        }
    }

    func testXKCDWordsCount() {
        [
            PasswordGenerator(flavor: .xkcd, length: 4, useSpecialSymbols: false),
            PasswordGenerator(flavor: .xkcd, length: 8, useSpecialSymbols: false),
            PasswordGenerator(flavor: .xkcd, length: 1, useSpecialSymbols: false),
        ].forEach { generator in
            XCTAssertEqual(generator.generate().split { "0123456789".contains($0) }.count, generator.limitedLength)
        }
    }

    func testRandomPasswordLength() {
        [
            PasswordGenerator(),
            PasswordGenerator(groups: 1),
            PasswordGenerator(length: 25),
            PasswordGenerator(length: 47, groups: 12),
            PasswordGenerator(useDigits: true),
        ].forEach { generator in
            XCTAssertEqual(generator.generate().count, generator.length)
        }
    }

    func testXKCDPasswordGeneration() {
        let typicalPassword = PasswordGenerator(flavor: .xkcd).generate()
        XCTAssertFalse(typicalPassword.isEmpty)
        XCTAssertFalse(typicalPassword.trimmingCharacters(in: .letters).isEmpty)

        let passwordWithoutSeparators = PasswordGenerator(flavor: .xkcd, useDigits: false, useSpecialSymbols: false).generate()
        XCTAssertFalse(passwordWithoutSeparators.isEmpty)
        XCTAssertTrue(passwordWithoutSeparators.trimmingCharacters(in: .letters).isEmpty)
    }
}
