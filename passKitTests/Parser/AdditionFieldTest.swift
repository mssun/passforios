//
//  AdditionFieldTest.swift
//  passKitTests
//
//  Created by Danny Moesch on 30.09.18.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

import XCTest

@testable import passKit

class AdditionFieldTest: XCTestCase {

    func testAdditionField() {
        let field1 = AdditionField(title: "key", content: "value")
        let field2 = AdditionField(title: "no content")
        let field3 = AdditionField(content: "no title")

        XCTAssertEqual(field1.asString, "key: value")
        XCTAssertEqual(field2.asString, "no content: ")
        XCTAssertEqual(field3.asString, "no title")

        XCTAssertTrue(field1.asTuple == ("key", "value"))
        XCTAssertTrue(field2.asTuple == ("no content", ""))
        XCTAssertTrue(field3.asTuple == ("", "no title"))
    }

    func testAdditionFieldEquals() {
        XCTAssertEqual("key" => "value", "key" => "value")
        XCTAssertNotEqual("key" => "value", "key" => "some other value")
    }

    func testInfixAdditionFieldInitialization() {
        XCTAssertEqual("key" => "value", AdditionField(title: "key", content: "value"))
    }

    func testAdditionFieldOperators() {
        let field1 = "key" => "value"
        let field2 = "some other key" => "some other value"
        let field3 = "" => "no title"

        XCTAssertEqual("start" | field1, "start\nkey: value")
        XCTAssertEqual("" | field1, "\nkey: value")
        XCTAssertEqual(field1 | "end", "key: value\nend")
        XCTAssertEqual(field1 | "", "key: value")
        XCTAssertEqual("start" | field1 | field2, "start\nkey: value\nsome other key: some other value")
        XCTAssertEqual(field1 | field2 | "end", "key: value\nsome other key: some other value\nend")
        XCTAssertEqual(field1 | field2 | field3, "key: value\nsome other key: some other value\nno title")
        XCTAssertEqual("check" => "for right" | "operator" => "precedence", "check: for right\noperator: precedence")
    }
}
