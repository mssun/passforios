//
//  PasswordGeneratorFlavorTest.swift
//  passKitTests
//
//  Created by Danny Moesch on 28.11.18.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

import XCTest

@testable import passKit

class PasswordGeneratorFlavorTest: XCTestCase {
    func testLengthLimits() {
        // Ensure properly chosen length limits. So this check no longer needs to be performed in the code.
        PasswordGeneratorFlavor.allCases.map(\.lengthLimits).forEach {
            XCTAssertLessThanOrEqual($0.min, $0.max)
        }
    }
}
