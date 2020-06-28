//
//  TestBase.swift
//  passKitTests
//
//  Created by Danny Moesch on 08.12.18.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

import XCTest

@testable import passKit

let PASSWORD_PATH = "/path/to/password"
let PASSWORD_URL = URL(fileURLWithPath: "/path/to/password")
let PASSWORD_STRING = "abcd1234"
let TOTP_URL = "otpauth://totp/email@email.com?secret=abcd1234"
let HOTP_URL = "otpauth://hotp/email@email.com?secret=abcd1234"

let FIELD = "key" => "value"
let SECURE_URL_FIELD = "url" => "https://secure.com"
let INSECURE_URL_FIELD = "url" => "http://insecure.com"
let LOGIN_FIELD = "login" => "login name"
let USERNAME_FIELD = "username" => "微 分 方 程"
let NOTE_FIELD = "note" => "A NOTE"
let HINT_FIELD = "some hints" => "äöüß // €³ %% −° && @²` | [{\\}],.<>"
let TOTP_URL_FIELD = "otpauth" => "//totp/email@email.com?secret=abcd1234"

let MULTILINE_BLOCK_START = "multiline block" => "|"
let MULTILINE_LINE_START = "multiline line" => ">"

func getPasswordObjectWith(content: String, url: URL? = nil) -> Password {
    Password(name: "password", url: url ?? PASSWORD_URL, plainText: content)
}

func assertDefaults(in password: Password, with passwordString: String, and additions: String,
                    at file: StaticString = #file, line: UInt = #line) {
    let fileContent = (passwordString | additions).data(using: .utf8)
    XCTAssertEqual(password.password, passwordString, "Actual passwords do not match.", file: file, line: line)
    XCTAssertEqual(password.plainData, fileContent, "Plain data are not equal.", file: file, line: line)
    XCTAssertEqual(password.additionsPlainText, additions, "Plain texts are not equal.", file: file, line: line)
    XCTAssertEqual(password.numberOfUnknowns, 0, "Number of unknowns is not 0.", file: file, line: line)
    XCTAssertEqual(password.numberOfOtpRelated, 0, "Number of OTP related fields is not 0.", file: file, line: line)
    XCTAssertEqual(password.otpType, .none, "OTP type is not .none.", file: file, line: line)
}

infix operator ∈: AdditionPrecedence
func ∈ (field: AdditionField, password: Password) -> Bool {
    password.getFilteredAdditions().contains(field)
}

infix operator ∉: AdditionPrecedence
func ∉ (field: AdditionField, password: Password) -> Bool {
    !(field ∈ password)
}
