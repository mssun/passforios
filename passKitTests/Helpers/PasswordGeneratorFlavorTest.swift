//
//  PasswordGeneratorFlavorTest.swift
//  passKitTests
//
//  Created by Danny Moesch on 28.11.18.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

import KeychainAccess
import XCTest

@testable import passKit

class PasswordGeneratorFlavorTest: XCTestCase {

    private let KEYCHAIN_PASSWORD_LENGTH = Keychain.generatePassword().count

    func testLocalizedName() {
        XCTAssertEqual(PasswordGeneratorFlavor.apple.localized, "Apple".localize())
        XCTAssertEqual(PasswordGeneratorFlavor.random.localized, "Random".localize())
    }

    func testDefaultLength() {
        // Ensure properly chosen default length values. So this check no longer needs to be performed in the code.
        PasswordGeneratorFlavor.allCases.map { $0.defaultLength }.forEach { defaultLength in
            XCTAssertLessThanOrEqual(defaultLength.min, defaultLength.max)
            XCTAssertLessThanOrEqual(defaultLength.def, defaultLength.max)
            XCTAssertGreaterThanOrEqual(defaultLength.def, defaultLength.min)
        }
    }

    func testGeneratePassword() {
        let apple = PasswordGeneratorFlavor.apple
        let random = PasswordGeneratorFlavor.random

        XCTAssertEqual(apple.generate(length: 4).count, KEYCHAIN_PASSWORD_LENGTH)
        XCTAssertEqual(random.generate(length: 0).count, 0)
        XCTAssertEqual(random.generate(length: 4).count, 4)
        XCTAssertEqual(random.generate(length: 100).count, 100)
    }
}
