//
//  Password.swift
//  pass
//
//  Created by Mingshen Sun on 2/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import SwiftyUserDefaults
import OneTimePassword
import Base32

public struct AdditionField: Equatable {
    public var title: String = ""
    public var content: String = ""

    var asString: String { return title.isEmpty ? content : title + ": " + content }
    var asTuple: (String, String) { return (title, content) }

    public static func == (first: AdditionField, second: AdditionField) -> Bool {
        return first.asTuple == second.asTuple
    }
}

public enum OtpType {
    case totp, hotp, none

    static func from(token: Token?) -> OtpType {
        switch token?.generator.factor {
        case .some(.counter):
            return .hotp
        case .some(.timer):
            return .totp
        default:
            return .none
        }
    }
}

enum PasswordChange: Int {
    case path = 0x01
    case content = 0x02
    case none = 0x00
}

public class Password {
    public static let OTP_KEYWORDS = ["otp_secret", "otp_type", "otp_algorithm", "otp_period", "otp_digits", "otp_counter", "otpauth"]

    public static let BLANK = " "
    public static let MULTILINE_WITH_LINE_BREAK_INDICATOR = "|"
    public static let MULTILINE_WITH_LINE_BREAK_SEPARATOR = "\n"
    public static let MULTILINE_WITHOUT_LINE_BREAK_INDICATOR = ">"
    public static let MULTILINE_WITHOUT_LINE_BREAK_SEPARATOR = BLANK

    private static let OTPAUTH = "otpauth"
    private static let OTPAUTH_URL_START = "\(OTPAUTH)://"
    private static let PASSWORD_KEYWORD = "password"
    private static let USERNAME_KEYWORD = "username"
    private static let LOGIN_KEYWORD = "login"
    private static let URL_KEYWORD = "url"
    private static let UNKNOWN = "unknown"

    public var name = ""
    public var url: URL?
    public var namePath: String { return url?.deletingPathExtension().path ?? "" }

    public var password = ""
    public var changed: Int = 0
    public var plainText = ""
    public var plainData: Data { return plainText.data(using: .utf8)! }
    public var username: String? { return getAdditionValue(withKey: Password.USERNAME_KEYWORD, caseSensitive: false) }
    public var login: String? { return getAdditionValue(withKey: Password.LOGIN_KEYWORD, caseSensitive: false) }
    public var urlString: String? { return getAdditionValue(withKey: Password.URL_KEYWORD, caseSensitive: false) }

    private var additions = [AdditionField]()
    private var firstLineIsOTPField = false
    private var otpToken: Token?
    public var otpType: OtpType { return OtpType.from(token: self.otpToken) }

    public init(name: String, url: URL?, plainText: String) {
        self.initEverything(name: name, url: url, plainText: plainText)
    }
    
    public func updatePassword(name: String, url: URL?, plainText: String) {
        if self.plainText != plainText || self.url != url {
            if self.plainText != plainText {
                changed = changed|PasswordChange.content.rawValue
            }
            if self.url != url {
                changed = changed|PasswordChange.path.rawValue
            }
            self.initEverything(name: name, url: url, plainText: plainText)
        }
    }
    
    private func initEverything(name: String, url: URL?, plainText: String) {
        self.name = name
        self.url = url
        self.plainText = plainText
        additions.removeAll()
        
        // split the plain text
        let plainTextSplit = self.plainText
            .split(omittingEmptySubsequences: false) { $0 == "\n" || $0 == "\r\n" }
            .map(String.init)

        // get password
        password = plainTextSplit.first ?? ""

        // get remaining lines (filter out empty lines)
        let additionalLines = plainTextSplit[1...].filter { !$0.isEmpty }

        // parse lines to get key-value pairs
        parseDataFrom(lines: additionalLines)

        // check whether the first line looks like an otp entry
        checkPasswordForOtpToken()

        // construct the otp token
        updateOtpToken()
    }

    private func parseDataFrom(lines: [String]) {
        var unknownIndex = 0
        var i = lines.startIndex
        while i < lines.count {
            let line = lines[i]
            i += 1
            var (key, value) = Password.getKeyValuePair(from: line)
            if key == nil {
                unknownIndex += 1
                key = "\(Password.UNKNOWN) \(unknownIndex)"
            } else if value == Password.MULTILINE_WITH_LINE_BREAK_INDICATOR {
                value = gatherMultilineValue(from: lines, startingAt: &i, removingLineBreaks: false)
            } else if value == Password.MULTILINE_WITHOUT_LINE_BREAK_INDICATOR {
                value = gatherMultilineValue(from: lines, startingAt: &i, removingLineBreaks: true)
            }
            additions.append(AdditionField(title: key!, content: value))
        }
    }

    private func gatherMultilineValue(from content: [String], startingAt i: inout Int, removingLineBreaks: Bool) -> String {
        var result = ""
        guard i < content.count else { return result }
        let numberInitialBlanks = content[i].enumerated().first(where: { $1 != Character(Password.BLANK) })?.0 ?? content[i].count
        guard numberInitialBlanks != 0 else { return result }
        let initialBlanks = String(repeating: Password.BLANK, count: numberInitialBlanks)
        
        while i < content.count && content[i].starts(with: initialBlanks) {
            result.append(String(content[i].dropFirst(numberInitialBlanks)))
            result.append(removingLineBreaks ? Password.MULTILINE_WITHOUT_LINE_BREAK_SEPARATOR : Password.MULTILINE_WITH_LINE_BREAK_SEPARATOR)
            i += 1
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func checkPasswordForOtpToken() {
        let (key, value) = Password.getKeyValuePair(from: self.password)
        if Password.OTP_KEYWORDS.contains(key ?? "") {
            firstLineIsOTPField = true
            self.additions.append(AdditionField(title: key!, content: value))
        } else {
            firstLineIsOTPField = false
        }
    }

    public func getFilteredAdditions() -> [AdditionField] {
        return additions.filter { field in
            field.title.lowercased() != Password.USERNAME_KEYWORD
            && field.title.lowercased() != Password.LOGIN_KEYWORD
            && field.title.lowercased() != Password.PASSWORD_KEYWORD
            && (!field.title.hasPrefix(Password.UNKNOWN) || !SharedDefaults[.isHideUnknownOn])
            && (!Password.OTP_KEYWORDS.contains(field.title) || !SharedDefaults[.isHideOTPOn])
        }
    }
    
    // return a key-value pair from the line
    // key might be nil, if there is no ":" in the line
    private static func getKeyValuePair(from line: String) -> (key: String?, value: String) {
        let items = line.components(separatedBy: ": ").map{String($0).trimmingCharacters(in: .whitespaces)}
        var key : String? = nil
        var value = ""
        if items.count == 1 || (items[0].isEmpty && items[1].isEmpty) {
            // no ": " found, or empty on both sides of ": "
            value = line
            // otpauth special case
            if value.hasPrefix(Password.OTPAUTH_URL_START) {
                key = Password.OTPAUTH
            }
        } else {
            if !items[0].isEmpty {
                key = items[0]
            }
            value = items[1]
        }
        return (key, value)
    }
    
    public func getAdditionsPlainText() -> String {
        // lines starting from the second
        let plainTextSplit = plainText.split(maxSplits: 1, omittingEmptySubsequences: false) {
            $0 == "\n" || $0 == "\r\n"
            }.map(String.init)
        return plainTextSplit.count == 1 ? "" : plainTextSplit[1]
    }
    
    private func getAdditionValue(withKey key: String, caseSensitive: Bool = true) -> String? {
        let searchKey = caseSensitive ? key : key.lowercased()
        let matchingField = additions.first { (caseSensitive ? $0.title : $0.title.lowercased()) == searchKey }
        return matchingField?.content
    }
    
    /*
     Set otpType and otpToken, if we are able to construct a valid token.
     
     Example of TOTP otpauth
     (Key Uri Format: https://github.com/google/google-authenticator/wiki/Key-Uri-Format)
     otpauth://totp/totp-secret?secret=AAAAAAAAAAAAAAAA&issuer=totp-secret
     
     Example of TOTP fields [Legacy, lower priority]
     otp_secret: secretsecretsecretsecretsecretsecret
     otp_type: totp
     otp_algorithm: sha1 (default: sha1, optional)
     otp_period: 30 (default: 30, optional)
     otp_digits: 6 (default: 6, optional)
     
     Example of HOTP fields [Legacy, lower priority]
     otp_secret: secretsecretsecretsecretsecretsecret
     otp_type: hotp
     otp_counter: 1
     otp_digits: 6 (default: 6, optional)
     
     */
    private func updateOtpToken() {
        self.otpToken = nil
        
        // get otpauth, if we are able to generate a token, return
        if var otpauthString = getAdditionValue(withKey: Password.OTPAUTH) {
            if !otpauthString.hasPrefix("\(Password.OTPAUTH):") {
                otpauthString = "\(Password.OTPAUTH):\(otpauthString)"
            }
            if let otpauthUrl = URL(string: otpauthString),
                let token = Token(url: otpauthUrl) {
                self.otpToken = token
                return
            }
        }
        
        // get secret data
        guard let secretString = getAdditionValue(withKey: "otp_secret"),
            let secretData = MF_Base32Codec.data(fromBase32String: secretString),
            !secretData.isEmpty else {
                // print("Missing / Invalid otp secret")
                return
        }
        
        // get type
        guard let type = getAdditionValue(withKey: "otp_type")?.lowercased(),
            (type == "totp" || type == "hotp") else {
                // print("Missing  / Invalid otp type")
                return
        }
        
        // get algorithm (optional)
        var algorithm = Generator.Algorithm.sha1
        if let algoString = getAdditionValue(withKey: "otp_algorithm") {
            switch algoString.lowercased() {
                case "sha256":
                    algorithm = .sha256
                case "sha512":
                    algorithm = .sha512
                default:
                    algorithm = .sha1
            }
        }
    
        // construct the token
        if type == "totp" {
            // HOTP
            // default: 6 digits, 30 seconds
            guard let digits = Int(getAdditionValue(withKey: "otp_digits") ?? "6"),
                let period = Double(getAdditionValue(withKey: "otp_period") ?? "30.0") else {
                    let alertMessage = "Invalid otp_digits or otp_period."
                    print(alertMessage)
                    return
            }
            guard let generator = Generator(
                factor: .timer(period: period),
                secret: secretData,
                algorithm: algorithm,
                digits: digits) else {
                    let alertMessage = "Invalid OTP generator parameters."
                    print(alertMessage)
                    return
            }
            self.otpToken = Token(name: self.name, issuer: "", generator: generator)
        } else {
            // HOTP
            // default: 6 digits
            guard let digits = Int(getAdditionValue(withKey: "otp_digits") ?? "6"),
                let counter = UInt64(getAdditionValue(withKey: "otp_counter") ?? "") else {
                    let alertMessage = "Invalid otp_digits or otp_counter."
                    print(alertMessage)
                    return
            }
            guard let generator = Generator(
                factor: .counter(counter),
                secret: secretData,
                algorithm: algorithm,
                digits: digits) else {
                    let alertMessage = "Invalid OTP generator parameters."
                    print(alertMessage)
                    return
            }
            self.otpToken = Token(name: self.name, issuer: "", generator: generator)
        }
    }
    
    // return the description and the password strings
    public func getOtpStrings() -> (description: String, otp: String)? {
        guard let token = self.otpToken else {
            return nil
        }
        var description : String
        switch token.generator.factor {
        case .counter:
            // htop
            description = "HMAC-based"
        case .timer(let period):
            // totp
            let timeSinceEpoch = Date().timeIntervalSince1970
            let validTime = Int(period - timeSinceEpoch.truncatingRemainder(dividingBy: period))
            description = "time-based (expiring in \(validTime)s)"
        }
        let otp = self.otpToken?.currentPassword ?? "error"
        return (description, otp)
    }
    
    // return the password strings
    public func getOtp() -> String? {
        return self.otpToken?.currentPassword
    }
    
    // return the password strings
    // it is guaranteed that it is a HOTP password when we call this
    public func getNextHotp() -> String? {
        // increase the counter
        otpToken = otpToken?.updatedToken()
        
        // replace old HOTP settings with the new otpauth
        var newOtpauth = try! otpToken?.toURL().absoluteString
        newOtpauth?.append("&secret=")
        newOtpauth?.append(MF_Base32Codec.base32String(from: otpToken?.generator.secret))
        
        var lines : [String] = []
        self.plainText.enumerateLines() { line, _ in
            let (key, _) = Password.getKeyValuePair(from: line)
            if !Password.OTP_KEYWORDS.contains(key ?? "") {
                lines.append(line)
            } else if key == Password.OTPAUTH && newOtpauth != nil {
                lines.append(newOtpauth!)
                // set to nil to prevent duplication
                newOtpauth = nil
            }
        }
        if newOtpauth != nil {
            lines.append(newOtpauth!)
        }
        self.updatePassword(name: self.name, url: self.url, plainText: lines.joined(separator: "\n"))
        
        // get and return the password
        return self.otpToken?.currentPassword
    }
    
    public static func LooksLikeOTP(line: String) -> Bool {
        let (key, _) = getKeyValuePair(from: line)
        return Password.OTP_KEYWORDS.contains(key ?? "")
    }
}
