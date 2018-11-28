//
//  PasswordGeneratorFlavourTest.swift
//  passKitTests
//
//  Created by Danny Moesch on 28.11.18.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

import KeychainAccess
import XCTest

@testable import passKit

class PasswordGeneratorFlavourTest: XCTestCase {

    private let KEYCHAIN_PASSWORD_LENGTH = Keychain.generatePassword().count

    func testFrom() {
        XCTAssertEqual(PasswordGeneratorFlavour.from("Apple"), PasswordGeneratorFlavour.APPLE)
        XCTAssertEqual(PasswordGeneratorFlavour.from("Random"), PasswordGeneratorFlavour.RANDOM)
        XCTAssertEqual(PasswordGeneratorFlavour.from("Something"), PasswordGeneratorFlavour.RANDOM)
        XCTAssertEqual(PasswordGeneratorFlavour.from(""), PasswordGeneratorFlavour.RANDOM)
    }

    func testDefaultLength() {
        // Ensure properly chosen default length values. So this check no longer needs to be performed in the code.
        PasswordGeneratorFlavour.allCases.map { $0.defaultLength }.forEach { defaultLength in
            XCTAssertLessThanOrEqual(defaultLength.min, defaultLength.max)
            XCTAssertLessThanOrEqual(defaultLength.def, defaultLength.max)
            XCTAssertGreaterThanOrEqual(defaultLength.def, defaultLength.min)
        }
    }

    func testGeneratePassword() {
        let apple = PasswordGeneratorFlavour.APPLE
        let random = PasswordGeneratorFlavour.RANDOM

        XCTAssertEqual(apple.generatePassword(length: 4).count, KEYCHAIN_PASSWORD_LENGTH)
        XCTAssertEqual(random.generatePassword(length: 0).count, 0)
        XCTAssertEqual(random.generatePassword(length: 4).count, 4)
        XCTAssertEqual(random.generatePassword(length: 100).count, 100)
    }
}
