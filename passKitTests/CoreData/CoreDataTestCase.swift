//
//  CoreDataTestCase.swift
//  pass
//
//  Created by Mingshen Sun on 1/4/25.
//  Copyright © 2025 Bob Sun. All rights reserved.
//

import CoreData
import Foundation
import XCTest

@testable import passKit

// swiftlint:disable:next final_test_case
class CoreDataTestCase: XCTestCase {
    // swiftlint:disable:next test_case_accessibility
    private(set) var controller: PersistenceController!

    override func setUpWithError() throws {
        try super.setUpWithError()

        controller = PersistenceController(isUnitTest: true)
        controller.setup()
    }

    override func tearDown() {
        super.tearDown()
        controller = nil
    }
}
