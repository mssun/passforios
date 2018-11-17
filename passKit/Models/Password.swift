//
//  Password.swift
//  pass
//
//  Created by Mingshen Sun on 2/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import SwiftyUserDefaults
import OneTimePassword
import Base32
import KeychainAccess

public class Password {
    
    public var name: String
    public var url: URL
    public var plainText: String

    public var changed: Int = 0
    public var otpType: OtpType = .none

    private var parser = Parser(plainText: "")
    private var additions = [AdditionField]()
    private var firstLineIsOTPField = false
    private var otpToken: Token? {
        didSet {
            otpType = OtpType(token: otpToken)
        }
    }

    public var namePath: String {
        return url.deletingPathExtension().path
    }

    public var password: String {
        return parser.firstLine
    }

    public var plainData: Data {
        return plainText.data(using: .utf8)!
    }

    public var additionsPlainText: String {
        return parser.additionsSection
    }

    public var username: String? {
        return getAdditionValue(withKey: Constants.USERNAME_KEYWORD)
    }

    public var login: String? {
        return getAdditionValue(withKey: Constants.LOGIN_KEYWORD)
    }
    
    public var urlString: String? {
        return getAdditionValue(withKey: Constants.URL_KEYWORD)
    }

    public init(name: String, url: URL, plainText: String) {
        self.name = name
        self.url = url
        self.plainText = plainText
        initEverything()
    }
    

    public func updatePassword(name: String, url: URL, plainText: String) {
        guard self.plainText != plainText || self.url != url else {
            return
        }

        if self.plainText != plainText {
            self.plainText = plainText
            changed = changed|PasswordChange.content.rawValue
        }
        if self.url != url {
            self.url = url
            changed = changed|PasswordChange.path.rawValue
        }

        self.name = name
        initEverything()
    }

    private func initEverything() {
        parser = Parser(plainText: self.plainText)
        additions = parser.additionFields

        // Check whether the first line looks like an otp entry.
        checkPasswordForOtpToken()

        // Construct the otp token.
        updateOtpToken()
    }

    private func checkPasswordForOtpToken() {
        let (key, value) = Parser.getKeyValuePair(from: password)
        if Constants.OTP_KEYWORDS.contains(key ?? "") {
            firstLineIsOTPField = true
            additions.append(key! => value)
        } else {
            firstLineIsOTPField = false
        }
    }

    public func getFilteredAdditions() -> [AdditionField] {
        return additions.filter { field in
            field.title.lowercased() != Constants.USERNAME_KEYWORD
            && field.title.lowercased() != Constants.LOGIN_KEYWORD
            && field.title.lowercased() != Constants.PASSWORD_KEYWORD
            && (!field.title.hasPrefix(Constants.UNKNOWN) || !SharedDefaults[.isHideUnknownOn])
            && (!Constants.OTP_KEYWORDS.contains(field.title) || !SharedDefaults[.isHideOTPOn])
        }
    }

    private func getAdditionValue(withKey key: String, caseSensitive: Bool = false) -> String? {
        let toLowercase = { (string: String) -> String in return caseSensitive ? string : string.lowercased() }
        return additions.first(where: { toLowercase($0.title) == toLowercase(key) })?.content
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
        if var otpauthString = getAdditionValue(withKey: Constants.OTPAUTH, caseSensitive: true) {
            if !otpauthString.hasPrefix("\(Constants.OTPAUTH):") {
                otpauthString = "\(Constants.OTPAUTH):\(otpauthString)"
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
                // Missing / Invalid otp secret
                return
        }
        
        // get type
        guard let type = getAdditionValue(withKey: "otp_type")?.lowercased(),
            (type == "totp" || type == "hotp") else {
                // Missing / Invalid otp type
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
                    // Invalid otp_digits or otp_period.
                    return
            }
            guard let generator = Generator(
                factor: .timer(period: period),
                secret: secretData,
                algorithm: algorithm,
                digits: digits) else {
                    // Invalid OTP generator parameters.
                    return
            }
            self.otpToken = Token(name: self.name, issuer: "", generator: generator)
        } else {
            // HOTP
            // default: 6 digits
            guard let digits = Int(getAdditionValue(withKey: "otp_digits") ?? "6"),
                let counter = UInt64(getAdditionValue(withKey: "otp_counter") ?? "") else {
                    // Invalid otp_digits or otp_counter.
                    return
            }
            guard let generator = Generator(
                factor: .counter(counter),
                secret: secretData,
                algorithm: algorithm,
                digits: digits) else {
                    // Invalid OTP generator parameters.
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
            let (key, _) = Parser.getKeyValuePair(from: line)
            if !Constants.OTP_KEYWORDS.contains(key ?? "") {
                lines.append(line)
            } else if key == Constants.OTPAUTH && newOtpauth != nil {
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
    
    public static func generatePassword(length: Int) -> String{
        switch SharedDefaults[.passwordGeneratorFlavor] {
        case "Random":
            return randomString(length: length)
        case "Apple":
            return Keychain.generatePassword()
        default:
            return randomString(length: length)
        }
    }
    
    private static func randomString(length: Int) -> String {
        
        let letters : NSString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*_+-="
        let len = UInt32(letters.length)
        
        var randomString = ""
        
        for _ in 0 ..< length {
            let rand = arc4random_uniform(len)
            var nextChar = letters.character(at: Int(rand))
            randomString += NSString(characters: &nextChar, length: 1) as String
        }
        
        return randomString
    }
}
