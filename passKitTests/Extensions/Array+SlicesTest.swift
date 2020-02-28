//
//  Array+SlicesTest.swift
//  passKitTests
//
//  Created by Danny Moesch on 28.02.20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import XCTest

@testable import passKit

class ArraySlicesTest: XCTestCase {

    func testZeroCount() {
        XCTAssertEqual([1, 2, 3].slices(count: 0), [])
    }

    func testEmptyArray() {
        XCTAssertEqual(([] as [String]).slices(count: 4), [[], [], [], []])
    }

    func testSlices() {
        XCTAssertEqual([1, 2, 3].slices(count: 3), [[1], [2], [3]])
        XCTAssertEqual([1, 2, 3, 4].slices(count: 3), [[1], [2], [3, 4]])
        XCTAssertEqual([1, 2, 3, 4].slices(count: 2), [[1, 2], [3, 4]])
        XCTAssertEqual([1, 2, 3, 4, 5].slices(count: 2), [[1, 2], [3, 4, 5]])
    }
}
