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

struct AdditionField {
    var title: String
    var content: String
}

class Password {
    static let otpKeywords = ["otp_secret", "otp_type", "otp_algorithm", "otp_period", "otp_digits", "otp_counter", "otpauth"]
    
    var name = ""
    var password = ""
    var additions = [String: String]()
    var additionKeys = [String]()
    var changed = false
    var plainText = ""
    
    private var firstLineIsOTPField = false
    private var otpToken: Token?
    
    enum OtpType {
        case totp, hotp, none
    }
    
    var otpType: OtpType {
        get {
            guard let token = self.otpToken else {
                return OtpType.none
            }
            switch token.generator.factor {
            case .counter:
                return OtpType.hotp
            case .timer:
                return OtpType.totp
            }
        }
    }
    
    init(name: String, plainText: String) {
        self.initEverything(name: name, plainText: plainText)
    }
    
    func updatePassword(name: String, plainText: String) {
        if self.plainText != plainText {
            self.initEverything(name: name, plainText: plainText)
            changed = true
        }
    }
    
    private func initEverything(name: String, plainText: String) {
        self.name = name
        self.plainText = plainText
        self.additions.removeAll()
        self.additionKeys.removeAll()
        
        // get password and additional fields
        let plainTextSplit = plainText.characters.split(maxSplits: 1, omittingEmptySubsequences: false) {
            $0 == "\n" || $0 == "\r\n"
            }.map(String.init)
        self.password  = plainTextSplit.first ?? ""
        if plainTextSplit.count == 2 {
            (self.additions, self.additionKeys) = Password.getAdditionFields(from: plainTextSplit[1])
        }
        
        // check whether the first line of the plainText looks like an otp entry
        let (key, value) = Password.getKeyValuePair(from: self.password)
        if Password.otpKeywords.contains(key ?? "") {
            firstLineIsOTPField = true
            self.additions[key!] = value
            self.additionKeys.insert(key!, at: 0)
        } else {
            firstLineIsOTPField = false
        }
        
        // construct the otp token
        self.updateOtpToken()
    }
    
    func getUsername() -> String? {
        return getAdditionValue(withKey: "Username") ?? getAdditionValue(withKey: "username")
    }
    
    func getURLString() -> String? {
        return getAdditionValue(withKey: "URL") ?? getAdditionValue(withKey: "url") ?? getAdditionValue(withKey: "Url")
    }
    
    // return a key-value pair from the line
    // key might be nil, if there is no ":" in the line
    static private func getKeyValuePair(from line: String) -> (key: String?, value: String) {
        let items = line.components(separatedBy: ": ").map{String($0).trimmingCharacters(in: .whitespaces)}
        var key : String? = nil
        var value = ""
        if items.count == 1 || (items[0].isEmpty && items[1].isEmpty) {
            // no ": " found, or empty on both sides of ": "
            value = line
            // otpauth special case
            if value.hasPrefix("otpauth://") {
                key = "otpauth"
            }
        } else {
            if !items[0].isEmpty {
                key = items[0]
            }
            value = items[1]
        }
        return (key, value)
    }
    
    static private func getAdditionFields(from additionFieldsPlainText: String) -> ([String: String], [String]){
        var additions = [String: String]()
        var additionKeys = [String]()
        var unknownIndex = 0

        additionFieldsPlainText.enumerateLines() { line, _ in
            if line == "" {
                return
            }
            var (key, value) = getKeyValuePair(from: line)
            if key == nil {
                unknownIndex += 1
                key = "unknown \(unknownIndex)"
            }
            additions[key!] = value
            additionKeys.append(key!)
        }
        
        return (additions, additionKeys)
    }
    
    func getAdditionsPlainText() -> String {
        // lines starting from the second
        let plainTextSplit = plainText.characters.split(maxSplits: 1, omittingEmptySubsequences: false) {
            $0 == "\n" || $0 == "\r\n"
            }.map(String.init)
        if plainTextSplit.count == 1 {
            return ""
        } else {
            return plainTextSplit[1]
        }
    }
    
    private func getPlainText() -> String {
        return self.plainText
    }
    
    func getPlainData() -> Data {
        return getPlainText().data(using: .utf8)!
    }
    
    private func getAdditionValue(withKey key: String) -> String? {
        return self.additions[key]
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
        if var otpauthString = getAdditionValue(withKey: "otpauth") {
            if !otpauthString.hasPrefix("otpauth:") {
                otpauthString = "otpauth:\(otpauthString)"
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
    func getOtpStrings() -> (description: String, otp: String)? {
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
    func getOtp() -> String? {
        if let otp = self.otpToken?.currentPassword {
            return otp
        } else {
            return nil
        }
    }
    
    // return the password strings
    // it is guaranteed that it is a HOTP password when we call this
    func getNextHotp() -> String? {
        // increase the counter
        otpToken = otpToken?.updatedToken()
        
        // replace old HOTP settings with the new otpauth
        var newOtpauth = try! otpToken?.toURL().absoluteString
        newOtpauth?.append("&secret=")
        newOtpauth?.append(MF_Base32Codec.base32String(from: otpToken?.generator.secret))
        
        var lines : [String] = []
        self.plainText.enumerateLines() { line, _ in
            let (key, _) = Password.getKeyValuePair(from: line)
            if !Password.otpKeywords.contains(key ?? "") {
                lines.append(line)
            } else if key == "otpauth" && newOtpauth != nil {
                lines.append(newOtpauth!)
                // set to nil to prevent duplication
                newOtpauth = nil
            }
        }
        if newOtpauth != nil {
            lines.append(newOtpauth!)
        }
        self.updatePassword(name: self.name, plainText: lines.joined(separator: "\n"))
        
        // get and return the password
        return self.otpToken?.currentPassword
    }
    
    static func LooksLikeOTP(line: String) -> Bool {
        let (key, _) = getKeyValuePair(from: line)
        return Password.otpKeywords.contains(key ?? "")
    }
}
