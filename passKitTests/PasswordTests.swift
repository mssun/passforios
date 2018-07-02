//
//  PasswordTests.swift
//  passKitTests
//
//  Created by Danny Mösch on 02.05.18.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

import XCTest
@testable import passKit

class PasswordTest: XCTestCase {
    static let EMPTY_STRING = ""
    static let PASSWORD_NAME = "password"
    static let PASSWORD_PATH = "/path/to/\(PASSWORD_NAME)"
    static let PASSWORD_URL = URL(fileURLWithPath: PASSWORD_PATH)
    static let PASSWORD_STRING = "abcd1234"
    static let OTP_TOKEN = "otpauth://totp/email@email.com?secret=abcd1234"

    static let SECURE_URL_FIELD = AdditionField(title: "url", content: "https://secure.com")
    static let INSECURE_URL_FIELD = AdditionField(title: "url", content: "http://insecure.com")
    static let LOGIN_FIELD = AdditionField(title: "login", content: "login name")
    static let USERNAME_FIELD = AdditionField(title: "username", content: "some username")
    static let NOTE_FIELD = AdditionField(title: "note", content: "A NOTE")

    func testUrl() {
        let password1 = getPasswordObjectWith(content: PasswordTest.EMPTY_STRING)
        XCTAssertEqual(password1.namePath, PasswordTest.PASSWORD_PATH)

        let password2 = getPasswordObjectWith(content: PasswordTest.EMPTY_STRING, url: nil)
        XCTAssertEqual(password2.namePath, PasswordTest.EMPTY_STRING)
    }

    func testLooksLikeOTP() {
        XCTAssertTrue(Password.LooksLikeOTP(line: PasswordTest.OTP_TOKEN))
        XCTAssertFalse(Password.LooksLikeOTP(line: "no_auth://totp/blabla"))
    }

    func testEmptyFile() {
        let fileContent = PasswordTest.EMPTY_STRING
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, PasswordTest.EMPTY_STRING)
        XCTAssertEqual(password.getPlainData(), fileContent.data(using: .utf8))

        XCTAssertEqual(password.getAdditionsPlainText(), PasswordTest.EMPTY_STRING)
        XCTAssertTrue(password.getFilteredAdditions().isEmpty)

        XCTAssertNil(password.getUsername())
        XCTAssertNil(password.getURLString())
        XCTAssertNil(password.getLogin())
    }

    func testOneEmptyLine() {
        let fileContent = """

            """
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, PasswordTest.EMPTY_STRING)
        XCTAssertEqual(password.getPlainData(), fileContent.data(using: .utf8))

        XCTAssertEqual(password.getAdditionsPlainText(), PasswordTest.EMPTY_STRING)
        XCTAssertTrue(password.getFilteredAdditions().isEmpty)

        XCTAssertNil(password.getUsername())
        XCTAssertNil(password.getURLString())
        XCTAssertNil(password.getLogin())
    }

    func testSimplePasswordFile() {
        let passwordString = PasswordTest.PASSWORD_STRING
        let urlField = PasswordTest.SECURE_URL_FIELD
        let loginField = PasswordTest.LOGIN_FIELD
        let usernameField = PasswordTest.USERNAME_FIELD
        let noteField = PasswordTest.NOTE_FIELD
        let fileContent = """
            \(passwordString)
            \(urlField.asString)
            \(loginField.asString)
            \(usernameField.asString)
            \(noteField.asString)
            """
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, passwordString)
        XCTAssertEqual(password.getPlainData(), fileContent.data(using: .utf8))

        XCTAssertEqual(password.getAdditionsPlainText(), asPlainText(urlField, loginField, usernameField, noteField))
        XCTAssertTrue(does(password: password, contain: urlField))
        XCTAssertFalse(does(password: password, contain: loginField))
        XCTAssertFalse(does(password: password, contain: usernameField))
        XCTAssertTrue(does(password: password, contain: noteField))

        XCTAssertEqual(password.getURLString(), urlField.content)
        XCTAssertEqual(password.getLogin(), loginField.content)
        XCTAssertEqual(password.getUsername(), usernameField.content)
    }

    func testTwoPasswords() {
        let firstPasswordString = PasswordTest.PASSWORD_STRING
        let secondPasswordString = "efgh5678"
        let urlField = PasswordTest.INSECURE_URL_FIELD
        let fileContent = """
            \(firstPasswordString)
            \(secondPasswordString)
            \(urlField.asString)
            """
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, firstPasswordString)
        XCTAssertEqual(password.getPlainData(), fileContent.data(using: .utf8))
        XCTAssertEqual(password.getAdditionsPlainText(), asPlainText(secondPasswordString, urlField.asString))

        XCTAssertTrue(does(password: password, contain: urlField))
        XCTAssertTrue(does(password: password, contain: AdditionField(title: "unknown 1", content: secondPasswordString)))

        XCTAssertNil(password.getUsername())
        XCTAssertEqual(password.getURLString(), urlField.content)
        XCTAssertNil(password.getLogin())
    }

    func testNoPassword() {
        let urlField = PasswordTest.SECURE_URL_FIELD
        let noteField = PasswordTest.NOTE_FIELD
        let fileContent = """
            \(urlField.asString)
            \(noteField.asString)
            """
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, urlField.asString)
        XCTAssertEqual(password.getPlainData(), fileContent.data(using: .utf8))

        XCTAssertEqual(password.getAdditionsPlainText(), asPlainText(noteField))
        XCTAssertTrue(does(password: password, contain: noteField))

        XCTAssertNil(password.getUsername())
        XCTAssertNil(password.getURLString())
        XCTAssertNil(password.getLogin())
    }

    func testDuplicateKeys() {
        let passwordString = PasswordTest.PASSWORD_STRING
        let urlField1 = PasswordTest.SECURE_URL_FIELD
        let urlField2 = PasswordTest.INSECURE_URL_FIELD
        let fileContent = """
            \(passwordString)
            \(urlField1.asString)
            \(urlField2.asString)
            """
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, passwordString)
        XCTAssertEqual(password.getPlainData(), fileContent.data(using: .utf8))

        XCTAssertEqual(password.getAdditionsPlainText(), asPlainText(urlField1, urlField2))
        XCTAssertTrue(does(password: password, contain: urlField1))
        XCTAssertTrue(does(password: password, contain: urlField2))

        XCTAssertNil(password.getUsername())
        XCTAssertEqual(password.getURLString(), urlField1.content)
        XCTAssertNil(password.getLogin())
    }

    func testUnknownKeys() {
        let passwordString = PasswordTest.PASSWORD_STRING
        let value1 = "value 1"
        let value2 = "value 2"
        let value3 = "value 3"
        let value4 = "value 4"
        let noteField = PasswordTest.NOTE_FIELD
        let urlField = PasswordTest.SECURE_URL_FIELD
        let fileContent = """
            \(passwordString)
            \(value1)
            \(noteField.asString)
            \(value2)
            \(value3)
            \(urlField.asString)
            \(value4)
            """
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, passwordString)
        XCTAssertEqual(password.getPlainData(), fileContent.data(using: .utf8))

        XCTAssertEqual(password.getAdditionsPlainText(), asPlainText(value1, noteField.asString, value2, value3, urlField.asString, value4))
        XCTAssertTrue(does(password: password, contain: AdditionField(title: "unknown 1", content: value1)))
        XCTAssertTrue(does(password: password, contain: noteField))
        XCTAssertTrue(does(password: password, contain: AdditionField(title: "unknown 2", content: value2)))
        XCTAssertTrue(does(password: password, contain: AdditionField(title: "unknown 3", content: value3)))
        XCTAssertTrue(does(password: password, contain: urlField))
        XCTAssertTrue(does(password: password, contain: AdditionField(title: "unknown 4", content: value4)))

        XCTAssertNil(password.getUsername())
        XCTAssertEqual(password.getURLString(), urlField.content)
        XCTAssertNil(password.getLogin())
    }

    func testPasswordFileWithOtpToken() {
        let passwordString = PasswordTest.PASSWORD_STRING
        let noteField = PasswordTest.NOTE_FIELD
        let otpToken = PasswordTest.OTP_TOKEN
        let fileContent = """
            \(passwordString)
            \(noteField.asString)
            \(otpToken)
            """
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, passwordString)
        XCTAssertEqual(password.getPlainData(), fileContent.data(using: .utf8))

        XCTAssertEqual(password.getAdditionsPlainText(), asPlainText(noteField.asString, otpToken))

        XCTAssertEqual(password.otpType, OtpType.totp)
        XCTAssertNotNil(password.getOtp())
    }

    func testFirstLineIsOtpToken() {
        let otpToken = PasswordTest.OTP_TOKEN
        let fileContent = """
            \(otpToken)
            """
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, otpToken)
        XCTAssertEqual(password.getPlainData(), fileContent.data(using: .utf8))

        XCTAssertEqual(password.getAdditionsPlainText(), PasswordTest.EMPTY_STRING)

        XCTAssertNil(password.getUsername())
        XCTAssertNil(password.getURLString())
        XCTAssertNil(password.getLogin())

        XCTAssertEqual(password.otpType, OtpType.totp)
        XCTAssertNotNil(password.getOtp())
    }

    func testWrongOtpToken() {
        let otpToken = "otpauth://htop/blabla"
        let fileContent = """
            \(otpToken)
            """
        let password = getPasswordObjectWith(content: fileContent)

        XCTAssertEqual(password.password, otpToken)
        XCTAssertEqual(password.getPlainData(), fileContent.data(using: .utf8))

        XCTAssertEqual(password.getAdditionsPlainText(), PasswordTest.EMPTY_STRING)

        XCTAssertEqual(password.otpType, OtpType.none)
        XCTAssertNil(password.getOtp())
    }

    private func getPasswordObjectWith(content: String, url: URL? = PasswordTest.PASSWORD_URL) -> Password {
        return Password(name: PasswordTest.PASSWORD_NAME, url: url, plainText: content)
    }

    private func does(password: Password, contain field: AdditionField) -> Bool {
        return password.getFilteredAdditions().contains(field)
    }

    private func asPlainText(_ strings: String...) -> String {
        return strings.joined(separator: "\n")
    }
    private func asPlainText(_ fields: AdditionField...) -> String {
        return fields.map { $0.asString }.joined(separator: "\n")
    }
}
