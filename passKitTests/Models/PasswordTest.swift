//
//  PasswordTest.swift
//  passKitTests
//
//  Created by Danny Moesch on 02.05.18.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

import XCTest

@testable import passKit

class PasswordTest: XCTestCase {

    func testUrl() {
        let password = getPasswordObjectWith(content: "")

        XCTAssertEqual(password.url, PASSWORD_URL)
        XCTAssertEqual(password.namePath, PASSWORD_PATH)
    }

    func testEmptyFile() {
        [
            "",
            "\n",
        ].forEach { fileContent in
            let password = getPasswordObjectWith(content: fileContent)

            XCTAssertEqual(password.password, "")
            XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))
            XCTAssertEqual(password.additionsPlainText, "")
            XCTAssert(password.getFilteredAdditions().isEmpty)
            XCTAssertEqual(password.numberOfUnknowns, 0)

            XCTAssertNil(password.username)
            XCTAssertNil(password.urlString)
            XCTAssertNil(password.login)

            XCTAssertEqual(password.numberOfOtpRelated, 0)
        }
    }

    func testEmptyPassword() {
        let fileContent = "\n\(LOGIN_FIELD.asString)"
        let password = getPasswordObjectWith(content: fileContent)

        assertDefaults(in: password, with: "", and: LOGIN_FIELD.asString)

        XCTAssert(LOGIN_FIELD ∉ password)

        XCTAssertNil(password.username)
        XCTAssertNil(password.urlString)
        XCTAssertEqual(password.login, LOGIN_FIELD.content)
    }

    func testSimplePasswordFile() {
        let additions = SECURE_URL_FIELD | LOGIN_FIELD | USERNAME_FIELD | NOTE_FIELD
        let fileContent = PASSWORD_STRING | additions
        let password = getPasswordObjectWith(content: fileContent)

        assertDefaults(in: password, with: PASSWORD_STRING, and: additions)

        XCTAssert(SECURE_URL_FIELD ∈ password)
        XCTAssert(LOGIN_FIELD ∉ password)
        XCTAssert(USERNAME_FIELD ∉ password)
        XCTAssert(NOTE_FIELD ∈ password)

        XCTAssertEqual(password.urlString, SECURE_URL_FIELD.content)
        XCTAssertEqual(password.login, LOGIN_FIELD.content)
        XCTAssertEqual(password.username, USERNAME_FIELD.content)
    }

    func testTwoPasswords() {
        let additions = "efgh5678" | INSECURE_URL_FIELD
        let fileContent = PASSWORD_STRING | additions
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, PASSWORD_STRING)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))
        XCTAssertEqual(password.additionsPlainText, additions)
        XCTAssertEqual(password.numberOfUnknowns, 1)

        XCTAssert(INSECURE_URL_FIELD ∈ password)
        XCTAssert(Constants.unknown(1) => "efgh5678" ∈ password)

        XCTAssertNil(password.username)
        XCTAssertEqual(password.urlString, INSECURE_URL_FIELD.content)
        XCTAssertNil(password.login)

        XCTAssertEqual(password.numberOfOtpRelated, 0)
    }

    func testNoPassword() {
        let fileContent = SECURE_URL_FIELD | NOTE_FIELD
        let password = getPasswordObjectWith(content: fileContent)

        assertDefaults(in: password, with: SECURE_URL_FIELD.asString, and: NOTE_FIELD.asString)

        XCTAssert(NOTE_FIELD ∈ password)

        XCTAssertNil(password.username)
        XCTAssertNil(password.urlString)
        XCTAssertNil(password.login)
    }

    func testDuplicateKeys() {
        let additions = SECURE_URL_FIELD | INSECURE_URL_FIELD
        let fileContent = PASSWORD_STRING | additions
        let password = getPasswordObjectWith(content: fileContent)

        assertDefaults(in: password, with: PASSWORD_STRING, and: additions)

        XCTAssert(SECURE_URL_FIELD ∈ password)
        XCTAssert(INSECURE_URL_FIELD ∈ password)

        XCTAssertNil(password.username)
        XCTAssertEqual(password.urlString, SECURE_URL_FIELD.content)
        XCTAssertNil(password.login)
    }

    func testUnknownKeys() {
        let value1 = "value 1"
        let value2 = "value 2"
        let value3 = "value 3"
        let value4 = "value 4"
        let additions = value1 | NOTE_FIELD | value2 | value3 | SECURE_URL_FIELD | value4
        let fileContent = PASSWORD_STRING | additions
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, PASSWORD_STRING)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))
        XCTAssertEqual(password.additionsPlainText, additions)
        XCTAssertEqual(password.numberOfUnknowns, 4)

        XCTAssert(Constants.unknown(1) => value1 ∈ password)
        XCTAssert(NOTE_FIELD ∈ password)
        XCTAssert(Constants.unknown(2) => value2 ∈ password)
        XCTAssert(Constants.unknown(3) => value3 ∈ password)
        XCTAssert(SECURE_URL_FIELD ∈ password)
        XCTAssert(Constants.unknown(4) => value4 ∈ password)

        XCTAssertNil(password.username)
        XCTAssertEqual(password.urlString, SECURE_URL_FIELD.content)
        XCTAssertNil(password.login)

        XCTAssertEqual(password.numberOfOtpRelated, 0)
    }

    func testPasswordFileWithOtpToken() {
        let additions = NOTE_FIELD | TOTP_URL
        let fileContent = PASSWORD_STRING | additions
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, PASSWORD_STRING)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))
        XCTAssertEqual(password.additionsPlainText, additions)
        XCTAssertEqual(password.numberOfUnknowns, 0)

        XCTAssertEqual(password.numberOfOtpRelated, 1)
        XCTAssertEqual(password.otpType, .totp)
        XCTAssertNotNil(password.currentOtp)
    }

    func testFirstLineIsOtpToken() {
        let password = getPasswordObjectWith(content: TOTP_URL)

        XCTAssertEqual(password.password, TOTP_URL)
        XCTAssertEqual(password.plainData, TOTP_URL.data(using: .utf8))
        XCTAssertEqual(password.additionsPlainText, "")
        XCTAssertEqual(password.numberOfUnknowns, 0)

        XCTAssertNil(password.username)
        XCTAssertNil(password.urlString)
        XCTAssertNil(password.login)

        XCTAssertEqual(password.numberOfOtpRelated, 0)
        XCTAssertEqual(password.otpType, .totp)
        XCTAssertNotNil(password.currentOtp)
    }

    func testOtpTokenAsField() {
        let additions = TOTP_URL_FIELD.asString
        let fileContent = PASSWORD_STRING | additions
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, PASSWORD_STRING)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))
        XCTAssertEqual(password.additionsPlainText, additions)
        XCTAssertEqual(password.numberOfUnknowns, 0)

        XCTAssertEqual(password.numberOfOtpRelated, 1)
        XCTAssertEqual(password.otpType, .totp)
        XCTAssertNotNil(password.currentOtp)
    }

    func testOtpTokenFromFields() {
        let additions =
            Constants.OTP_SECRET => "secret" |
            Constants.OTP_TYPE => "hotp" |
            Constants.OTP_COUNTER => "12" |
            Constants.OTP_DIGITS => "7"
        let fileContent = PASSWORD_STRING | additions
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, PASSWORD_STRING)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))
        XCTAssertEqual(password.additionsPlainText, additions)
        XCTAssertEqual(password.numberOfUnknowns, 0)

        XCTAssertEqual(password.numberOfOtpRelated, 4)
        XCTAssertEqual(password.otpType, .hotp)
        XCTAssertNotNil(password.currentOtp)
    }

    func testWrongOtpToken() {
        let fileContent = "otpauth://htop/blabla"
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, fileContent)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))
        XCTAssert(password.additionsPlainText.isEmpty)
        XCTAssertEqual(password.numberOfUnknowns, 0)

        XCTAssertEqual(password.numberOfOtpRelated, 0)
        XCTAssertEqual(password.otpType, OtpType.none)
        XCTAssertNil(password.currentOtp)
    }

    func testEmptyMultilineValues() {
        let additions = MULTILINE_BLOCK_START | "\n" | MULTILINE_BLOCK_START | " \n" | NOTE_FIELD | MULTILINE_LINE_START
        let fileContent = PASSWORD_STRING | additions
        let password = getPasswordObjectWith(content: fileContent)

        assertDefaults(in: password, with: PASSWORD_STRING, and: additions)

        XCTAssert(MULTILINE_BLOCK_START.title => "" ∈ password)
        XCTAssert(MULTILINE_BLOCK_START.title => "" ∈ password)
        XCTAssert(NOTE_FIELD ∈ password)
        XCTAssert(MULTILINE_LINE_START.title => "" ∈ password)
    }

    func testMultilineValues() {
        let lineBreakField = "with line breaks" => "|\n  This is \n   text spread over \n  multiple lines!  "
        let noLineBreakField = "without line breaks" => " > \n This is \n  text spread over\n   multiple lines!"
        let additions = lineBreakField | NOTE_FIELD | noLineBreakField
        let fileContent = PASSWORD_STRING | additions
        let password = getPasswordObjectWith(content: fileContent)

        assertDefaults(in: password, with: PASSWORD_STRING, and: additions)

        XCTAssert(lineBreakField.title => "This is \n text spread over \nmultiple lines!" ∈ password)
        XCTAssert(NOTE_FIELD ∈ password)
        XCTAssert(noLineBreakField.title => "This is   text spread over   multiple lines!" ∈ password)
    }

    func testMultilineValuesMixed() {
        let lineBreakField = "with line breaks" => "|\n  This is \n  \(HINT_FIELD.asString) spread over\n multiple lines!"
        let noLineBreakField = "without line breaks" => " > \n This is \n | \n text spread over\nmultiple lines!"
        let additions = lineBreakField | noLineBreakField | NOTE_FIELD
        let fileContent = PASSWORD_STRING | additions
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, PASSWORD_STRING)
        XCTAssertEqual(password.plainData, fileContent.data(using: .utf8))
        XCTAssertEqual(password.additionsPlainText, additions)

        XCTAssert(lineBreakField.title => "This is \n\(HINT_FIELD.asString) spread over" ∈ password)
        XCTAssert(Constants.unknown(1) => " multiple lines!" ∈ password)
        XCTAssert(noLineBreakField.title => "This is  |  text spread over" ∈ password)
        XCTAssert(Constants.unknown(2) => "multiple lines!" ∈ password)
        XCTAssert(NOTE_FIELD ∈ password)
    }

    func testUpdatePassword() {
        let password = getPasswordObjectWith(content: "")
        XCTAssertEqual(password.changed, 0)

        password.updatePassword(name: "password", url: PASSWORD_URL, plainText: "")
        XCTAssertEqual(password.changed, 0)

        password.updatePassword(name: "", url: PASSWORD_URL, plainText: "a")
        XCTAssertEqual(password.changed, 2)

        password.updatePassword(name: "", url: URL(fileURLWithPath: "/some/path/"), plainText: "a")
        XCTAssertEqual(password.changed, 3)

        password.updatePassword(name: "", url: PASSWORD_URL, plainText: "")
        XCTAssertEqual(password.changed, 3)
    }

    func testOtpStringsNoOtpToken() {
        let password = getPasswordObjectWith(content: "")
        let otpStrings = password.getOtpStrings()

        XCTAssertNil(otpStrings)
    }

    func testOtpStringsTotpToken() {
        let password = getPasswordObjectWith(content: TOTP_URL)
        let otpStrings = password.getOtpStrings()
        let otpDescription = otpStrings!.description

        XCTAssertNotNil(otpStrings)
        XCTAssert(otpDescription.hasPrefix("TimeBased".localize() + " ("))
        XCTAssert(otpDescription.hasSuffix(")"))
    }

    func testOtpStringsHotpToken() {
        let password = getPasswordObjectWith(content: HOTP_URL)
        let otpStrings = password.getOtpStrings()

        XCTAssertNotNil(otpStrings)
        XCTAssertEqual(otpStrings!.description, "HmacBased".localize())
    }
}
