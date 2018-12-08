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

let SECURE_URL_FIELD = "url" => "https://secure.com"
let INSECURE_URL_FIELD = "url" => "http://insecure.com"
let LOGIN_FIELD = "login" => "login name"
let USERNAME_FIELD = "username" => "some username"
let NOTE_FIELD = "note" => "A NOTE"
let HINT_FIELD = "some hints" => "äöüß // €³ %% −° && @²` | [{\\}],.<>"
let TOTP_URL_FIELD = "otpauth" => "//totp/email@email.com?secret=abcd1234"

func getPasswordObjectWith(content: String, url: URL? = nil) -> Password {
    return Password(name: "password", url: url ?? PASSWORD_URL, plainText: content)
}

func does(_ password: Password, contain field: AdditionField) -> Bool {
    return password.getFilteredAdditions().contains(field)
}

