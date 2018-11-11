//
//  Constants.swift
//  passKit
//
//  Created by Danny Moesch on 16.08.18.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

public struct Constants {

    public static let OTP_KEYWORDS = [
        "otp_secret",
        "otp_type",
        "otp_algorithm",
        "otp_period",
        "otp_digits",
        "otp_counter",
        "otpauth",
    ]

    static let BLANK = " "
    static let MULTILINE_WITH_LINE_BREAK_INDICATOR = "|"
    static let MULTILINE_WITH_LINE_BREAK_SEPARATOR = "\n"
    static let MULTILINE_WITHOUT_LINE_BREAK_INDICATOR = ">"
    static let MULTILINE_WITHOUT_LINE_BREAK_SEPARATOR = BLANK

    static let OTPAUTH = "otpauth"
    static let OTPAUTH_URL_START = "\(OTPAUTH)://"
    static let PASSWORD_KEYWORD = "password"
    static let USERNAME_KEYWORD = "username"
    static let LOGIN_KEYWORD = "login"
    static let URL_KEYWORD = "url"
    static let UNKNOWN = "unknown"

    public static func isOtpRelated(line: String) -> Bool {
        let (key, _) = Parser.getKeyValuePair(from: line)
        return OTP_KEYWORDS.contains(key ?? "")
    }

    static func unknown(_ number: UInt) -> String {
        return "\(UNKNOWN) \(number)"
    }

    static func getSeparator(breakingLines: Bool) -> String {
        return breakingLines ? MULTILINE_WITH_LINE_BREAK_SEPARATOR : MULTILINE_WITHOUT_LINE_BREAK_SEPARATOR
    }
}
