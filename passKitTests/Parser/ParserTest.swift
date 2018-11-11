//
//  ParserTest.swift
//  passKitTests
//
//  Created by Danny Moesch on 18.08.18.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

@testable import passKit
import XCTest

class ParserTest: XCTestCase {

    private let FIELD = "key" => "value"
    private let LOGIN_FIELD = "login" => "login name"
    private let SECURE_URL_FIELD = "url" => "https://secure.com"
    private let INSECURE_URL_FIELD = "url" => "http://insecure.com"
    private let USERNAME_FIELD = "username" => "微 分 方 程"
    private let NOTE_FIELD = "note" => "A NOTE"
    private let MULTILINE_BLOCK_START = "multiline block" => "|"
    private let MULTILINE_LINE_START = "multiline line" => ">"

    func testInit() {
        [
            ("", "", "", []),
            ("a", "a", "", []),
            ("a\nb", "a", "b", ["b"]),
            ("a\n\nb", "a", "\nb", ["b"]),
            ("a\r\nb", "a", "b", ["b"]),
            ("a\nb\nc\n\nd", "a", "b\nc\n\nd", ["b", "c", "d"]),
        ].forEach { plainText, firstLine, additionsSection, purgedAdditionalLines in
            let parser = Parser(plainText: plainText)
            XCTAssertEqual(parser.firstLine, firstLine)
            XCTAssertEqual(parser.additionsSection, additionsSection)
            XCTAssertEqual(parser.purgedAdditionalLines, purgedAdditionalLines)
        }
    }

    func testGetKeyValuePair() {
        XCTAssertTrue(Parser.getKeyValuePair(from: "key: value") == ("key", "value"))
        XCTAssertTrue(Parser.getKeyValuePair(from: "a key: a value") == ("a key", "a value"))
        XCTAssertTrue(Parser.getKeyValuePair(from: "key:value") == (nil, "key:value"))
        XCTAssertTrue(Parser.getKeyValuePair(from: ": value") == (nil, "value"))
        XCTAssertTrue(Parser.getKeyValuePair(from: "key: ") == ("key", ""))
        XCTAssertTrue(Parser.getKeyValuePair(from: "otpauth://value") == ("otpauth", "otpauth://value"))
    }

    func testEmptyFiles() {
        XCTAssertEqual(Parser(plainText: "").additionFields, [])
        XCTAssertEqual(Parser(plainText: "\n").additionFields, [])
    }

    func testSimpleKeyValueLines() {
        let fields0 = Parser(plainText: "" | FIELD | LOGIN_FIELD | SECURE_URL_FIELD).additionFields
        let fields1 = Parser(plainText: "" | FIELD | "" | SECURE_URL_FIELD).additionFields

        XCTAssertEqual(fields0, [FIELD, LOGIN_FIELD, SECURE_URL_FIELD])
        XCTAssertEqual(fields1, [FIELD, SECURE_URL_FIELD])
    }

    func testLinesWithoutKey() {
        let fields0 = Parser(plainText: "" | "value").additionFields
        let fields1 = Parser(plainText: "" | LOGIN_FIELD | "value only" | INSECURE_URL_FIELD).additionFields
        let fields2 = Parser(plainText: "" | LOGIN_FIELD | USERNAME_FIELD | "value:only").additionFields
        let fields3 = Parser(plainText: "" | LOGIN_FIELD | "value 1" | "value 2").additionFields

        XCTAssertEqual(fields0, [Constants.unknown(1) => "value"])
        XCTAssertEqual(fields1, [LOGIN_FIELD, Constants.unknown(1) => "value only", INSECURE_URL_FIELD])
        XCTAssertEqual(fields2, [LOGIN_FIELD, USERNAME_FIELD, Constants.unknown(1) => "value:only"])
        XCTAssertEqual(fields3, [LOGIN_FIELD, Constants.unknown(1) => "value 1", Constants.unknown(2) => "value 2"])
    }

    func testMultilineValues() {
        [
            // Normal with one leading space
            (" a b" | " cd", "a b\ncd", []),
            // Normal with two leading spaces
            ("  a b" | "  cd", "a b\ncd", []),
            // Changing leading space lenght
            (" a b" | "  cd", "a b\n cd", []),
            // First leading space longer than others
            ("  a b" | " cd", "a b", [Constants.unknown(1) => " cd"]),
            // Empty first line
            ("  " | "  cd", "cd", []),
            // No leading space
            ("a b" | "cd", "", [Constants.unknown(1) => "a b", Constants.unknown(2) => "cd"]),
            // Characters with special meaning in value
            (" a: b" | " c: |" | " d", "a: b\nc: |\nd", []),
            // Empty value at end
            ("", "", []),
            // Empty value in between
            ("" | NOTE_FIELD, "", [NOTE_FIELD]),
        ].forEach { wrappedMultilineValue, content, additionalFields in
            let blockField = Parser(plainText: "" | MULTILINE_BLOCK_START | wrappedMultilineValue).additionFields
            XCTAssertEqual(blockField, [MULTILINE_BLOCK_START.title => content] + additionalFields)

            let lineField = Parser(plainText: "" | MULTILINE_LINE_START | wrappedMultilineValue).additionFields
            let contentWithoutLineBreaks = content.replacingOccurrences(of: "\n", with: " ")
            XCTAssertEqual(lineField, [MULTILINE_LINE_START.title => contentWithoutLineBreaks] + additionalFields)
        }
    }
}
