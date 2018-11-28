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
        guard let secretString = getAdditionValue(withKey: Constants.OTP_SECRET),
            let secretData = MF_Base32Codec.data(fromBase32String: secretString),
            !secretData.isEmpty else {
                // Missing / Invalid otp secret
                return
        }
        
        // get type
        guard let type = getAdditionValue(withKey: Constants.OTP_TYPE)?.lowercased(),
            (type == Constants.TOTP || type == Constants.HOTP) else {
                // Missing/Invalid OTP type
                return
        }
        
        // get algorithm (optional)
        var algorithm = Generator.Algorithm.sha1
        if let algoString = getAdditionValue(withKey: Constants.OTP_ALGORITHM) {
            switch algoString.lowercased() {
                case Constants.SHA256:
                    algorithm = .sha256
                case Constants.SHA512:
                    algorithm = .sha512
                default:
                    algorithm = .sha1
            }
        }
    
        // construct the token
        if type == Constants.TOTP {
            // HOTP
            // default: 6 digits, 30 seconds
            guard let digits = Int(getAdditionValue(withKey: Constants.OTP_DIGITS) ?? Constants.DEFAULT_DIGITS),
                let period = Double(getAdditionValue(withKey: Constants.OTP_PERIOD) ?? Constants.DEFAULT_PERIOD) else {
                    // Invalid OTP digits or OTP period.
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
            guard let digits = Int(getAdditionValue(withKey: Constants.OTP_DIGITS) ?? Constants.DEFAULT_DIGITS),
                let counter = UInt64(getAdditionValue(withKey: Constants.OTP_COUNTER) ?? Constants.DEFAULT_COUNTER) else {
                    // Invalid OTP digits or OTP counter.
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
}
