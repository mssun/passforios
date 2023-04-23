//
//  Password.swift
//  passKit
//
//  Created by Mingshen Sun on 2/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Base32
import OneTimePassword

public class Password {
    public var name: String
    public var url: URL
    public var plainText: String

    public var changed: Int = 0
    public var otpType: OTPType = .none

    private var parser = Parser(plainText: "")
    private var additions = [AdditionField]()
    private var firstLineIsOTPField = false

    private var otpToken: Token? {
        didSet {
            otpType = OTPType(token: otpToken)
        }
    }

    public var namePath: String {
        url.deletingPathExtension().path
    }

    public var nameFromPath: String? {
        url.deletingPathExtension().path.split(separator: "/").last.map { String($0) }
    }

    public var password: String {
        parser.firstLine
    }

    public var plainData: Data {
        plainText.data(using: .utf8)!
    }

    public var additionsPlainText: String {
        parser.additionsSection
    }

    public var username: String? {
        getAdditionValue(withKey: Constants.USERNAME_KEYWORD)
    }

    public var user: String? {
        getAdditionValue(withKey: Constants.USER_KEYWORD)
    }

    public var login: String? {
        getAdditionValue(withKey: Constants.LOGIN_KEYWORD)
    }

    public var urlString: String? {
        getAdditionValue(withKey: Constants.URL_KEYWORD)
    }

    public var currentOtp: String? {
        otpToken?.currentPassword
    }

    public var numberOfUnknowns: Int {
        additions.map(\.title).filter(Constants.isUnknown).count
    }

    public var numberOfOtpRelated: Int {
        additions.map(\.title).filter(Constants.isOtpKeyword).count - (firstLineIsOTPField ? 1 : 0)
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
            changed |= PasswordChange.content.rawValue
        }
        if self.url != url {
            self.url = url
            changed |= PasswordChange.path.rawValue
        }

        self.name = name
        initEverything()
    }

    private func initEverything() {
        parser = Parser(plainText: plainText)
        additions = parser.additionFields

        // Check whether the first line looks like an otp entry.
        checkPasswordForOtpToken()

        // Construct the otp token.
        updateOtpToken()
    }

    private func checkPasswordForOtpToken() {
        let (key, value) = Parser.getKeyValuePair(from: password)
        if let key, Constants.isOtpKeyword(key) {
            firstLineIsOTPField = true
            additions.append(key => value)
        } else {
            firstLineIsOTPField = false
        }
    }

    public func getFilteredAdditions() -> [AdditionField] {
        additions.filter { field in
            let title = field.title.lowercased()
            return title != Constants.USERNAME_KEYWORD
                && title != Constants.USER_KEYWORD
                && title != Constants.LOGIN_KEYWORD
                && title != Constants.PASSWORD_KEYWORD
                && (!Constants.isUnknown(title) || !Defaults.isHideUnknownOn)
                && (!Constants.isOtpKeyword(title) || !Defaults.isHideOTPOn)
        }
    }

    private func getAdditionValue(withKey key: String, caseSensitive: Bool = false) -> String? {
        let toLowercase = { (string: String) -> String in caseSensitive ? string : string.lowercased() }
        return additions.first { toLowercase($0.title) == toLowercase(key) }?.content
    }

    /// Set the OTP token if we are able to construct a valid one.
    ///
    /// Example of TOTP otpauth:
    ///
    ///     otpauth://totp/totp-secret?secret=AAAAAAAAAAAAAAAA&issuer=totp-secret
    ///
    /// See also [Key URI Format](https://github.com/google/google-authenticator/wiki/Key-URI-Format).
    ///
    /// In case no otpauth is given in the password file, try to construct the token from separate fields using a
    /// `TokenBuilder`. This means that tokens provided as otpauth have higher priority.
    ///
    private func updateOtpToken() {
        // Get otpauth. If we are able to generate a token, return.
        if var otpauthString = getAdditionValue(withKey: Constants.OTPAUTH, caseSensitive: true) {
            if !otpauthString.hasPrefix("\(Constants.OTPAUTH):") {
                otpauthString = "\(Constants.OTPAUTH):\(otpauthString)"
            }
            if let otpauthURL = URL(string: otpauthString), let token = Token(url: otpauthURL) {
                otpToken = token
                return
            }
        }

        // Construct OTP token from separate fields provided in the password file.
        otpToken = TokenBuilder()
            .usingName(name)
            .usingSecret(getAdditionValue(withKey: Constants.OTP_SECRET))
            .usingType(getAdditionValue(withKey: Constants.OTP_TYPE))
            .usingAlgorithm(getAdditionValue(withKey: Constants.OTP_ALGORITHM))
            .usingDigits(getAdditionValue(withKey: Constants.OTP_DIGITS))
            .usingPeriod(getAdditionValue(withKey: Constants.OTP_PERIOD))
            .usingCounter(getAdditionValue(withKey: Constants.OTP_COUNTER))
            .usingRepresentation(getAdditionValue(withKey: Constants.OTP_REPRESENTATION))
            .build()
    }

    /// Get the OTP description and the current password.
    public func getOtpStrings() -> (description: String, otp: String)? {
        guard otpToken != nil else {
            return nil
        }
        var description = otpType.description
        if case let .timer(period) = otpToken!.generator.factor {
            let timeSinceEpoch = Date().timeIntervalSince1970
            let validTime = Int(period - timeSinceEpoch.truncatingRemainder(dividingBy: period))
            description += " " + "ExpiresIn".localize(validTime)
        }
        return (description, otpToken!.currentPassword ?? "Error".localize())
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

        var lines: [String] = []
        plainText.enumerateLines { line, _ in
            let (key, _) = Parser.getKeyValuePair(from: line)
            if !Constants.OTP_KEYWORDS.contains(key ?? "") {
                lines.append(line)
            } else if key == Constants.OTPAUTH, newOtpauth != nil {
                lines.append(newOtpauth!)
                // set to nil to prevent duplication
                newOtpauth = nil
            }
        }
        if newOtpauth != nil {
            lines.append(newOtpauth!)
        }
        updatePassword(name: name, url: url, plainText: lines.joined(separator: "\n"))

        // get and return the password
        return otpToken?.currentPassword
    }

    public func getUsernameForCompletion() -> String {
        username ?? user ?? login ?? nameFromPath ?? ""
    }
}
