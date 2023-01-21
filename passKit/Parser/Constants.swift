//
//  Constants.swift
//  passKit
//
//  Created by Danny Moesch on 16.08.18.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

import OneTimePassword

public enum Constants {
    static let OTP_SECRET = "otp_secret"
    static let OTP_TYPE = "otp_type"
    static let OTP_ALGORITHM = "otp_algorithm"
    static let OTP_PERIOD = "otp_period"
    static let OTP_DIGITS = "otp_digits"
    static let OTP_COUNTER = "otp_counter"
    static let OTP_REPRESENTATION = "otp_representation"
    static let OTPAUTH = "otpauth"

    public static let OTP_KEYWORDS = [
        OTP_SECRET,
        OTP_TYPE,
        OTP_ALGORITHM,
        OTP_PERIOD,
        OTP_DIGITS,
        OTP_COUNTER,
        OTP_REPRESENTATION,
        OTPAUTH,
    ]

    static let TOTP = "totp"
    static let HOTP = "hotp"
    static let SHA256 = "sha256"
    static let SHA512 = "sha512"
    static let DEFAULT_DIGITS = 6
    static let DEFAULT_PERIOD = 30.0
    static let DEFAULT_COUNTER: UInt64? = nil
    static let DEFAULT_REPRESENTATION: OneTimePassword.Generator.Representation = .numeric

    static let BLANK = " "
    static let MULTILINE_WITH_LINE_BREAK_INDICATOR = "|"
    static let MULTILINE_WITH_LINE_BREAK_SEPARATOR = "\n"
    static let MULTILINE_WITHOUT_LINE_BREAK_INDICATOR = ">"
    static let MULTILINE_WITHOUT_LINE_BREAK_SEPARATOR = BLANK

    static let OTPAUTH_URL_START = "\(OTPAUTH)://"

    public static let PASSWORD_KEYWORD = "password"
    public static let USERNAME_KEYWORD = "username"
    public static let USER_KEYWORD = "user"
    public static let LOGIN_KEYWORD = "login"
    public static let URL_KEYWORD = "url"
    public static let UNKNOWN = "unknown"

    public static func isOtpRelated(line: String) -> Bool {
        let (key, _) = Parser.getKeyValuePair(from: line)
        return key != nil && isOtpKeyword(key!)
    }

    static func isOtpKeyword(_ keyword: String) -> Bool {
        OTP_KEYWORDS.contains(keyword.lowercased())
    }

    static func isUnknown(_ string: String) -> Bool {
        let components = string.components(separatedBy: " ")
        return components.count == 2 && components[0] == UNKNOWN && UInt(components[1]) != nil
    }

    static func unknown(_ number: UInt) -> String {
        "\(UNKNOWN) \(number)"
    }

    static func getSeparator(breakingLines: Bool) -> String {
        breakingLines ? MULTILINE_WITH_LINE_BREAK_SEPARATOR : MULTILINE_WITHOUT_LINE_BREAK_SEPARATOR
    }
}
