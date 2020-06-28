//
//  String+UtilitiesTest.swift
//  passKitTests
//
//  Created by Danny Moesch on 30.09.18.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

import XCTest

@testable import passKit

class StringUtilitiesTest: XCTestCase {
    func testTrimmed() {
        [
            ("  ", ""),
            (" \n\t\r", ""),
            ("\t  a \n b \t c \r d  \n ", "a \n b \t c \r d"),
        ].forEach { untrimmed, trimmed in
            XCTAssertEqual(untrimmed.trimmed, trimmed)
        }
    }

    func testStringByAddingPercentEncodingForRFC3986() {
        [
            ("!#$&'()*+,/:;=?@[]^", "%21%23%24%26%27%28%29%2A%2B%2C/%3A%3B%3D?%40%5B%5D%5E"),
            ("-._~/?", "-._~/?"),
            ("A*b!c", "A%2Ab%21c"),
        ].forEach { unencoded, encoded in
            XCTAssertEqual(unencoded.stringByAddingPercentEncodingForRFC3986(), encoded)
        }
    }

    func testConcatenateAsLines() {
        [
            ("a" | "b", "a\nb"),
            ("" | "b", "\nb"),
            ("a" | "", "a"),
            ("" | "", ""),
        ].forEach { concatenated, result in
            XCTAssertEqual(concatenated, result)
        }
    }
}
