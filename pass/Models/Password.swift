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
    static let otpKeywords = ["otp_secret", "otp_type", "otp_algorithm", "otp_period", "otp_digits", "otp_counter"]
    
    var name = ""
    var password = ""
    var additions = [String: String]()
    var additionKeys = [String]()
    var plainText = ""
    var changed = false
    var firstLineIsOTPField = false
    var otpType: String?
    var otpToken: Token?
    
    init(name: String, plainText: String) {
        self.initEverything(name: name, plainText: plainText)
    }
    
    func updatePassword(name: String, plainText: String) {
        if self.plainText != plainText {
            self.initEverything(name: name, plainText: plainText)
            changed = true
        }
    }
    
    func initEverything(name: String, plainText: String) {
        self.name = name
        self.plainText = plainText
        
        // get password and additional fields
        let plainTextSplit = plainText.characters.split(maxSplits: 1, omittingEmptySubsequences: false) {
            $0 == "\n" || $0 == "\r\n"
            }.map(String.init)
        self.password  = plainTextSplit[0]
        (self.additions, self.additionKeys) = Password.getAdditionFields(from: plainTextSplit[1])
        
        // check whether the first line of the plainText looks like an otp entry
        let (key, value) = Password.getKeyValuePair(from: plainTextSplit[0])
        if key != nil && Password.otpKeywords.contains(key!) {
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
    
    func getURL() -> String? {
        return getAdditionValue(withKey: "URL") ?? getAdditionValue(withKey: "url") ?? getAdditionValue(withKey: "Url")
    }
    
    // return a key-value pair from the line
    // key might be nil, if there is no ":" in the line
    static func getKeyValuePair(from line: String) -> (key: String?, value: String) {
        let items = line.characters.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)
        var key : String?
        var value = ""
        if items.count == 1 {
            value = items[0]
        } else if items.count == 2 {
            key = items[0]
            value = items[1].trimmingCharacters(in: .whitespaces)
        }
        return (key, value)
    }
    
    static func getAdditionFields(from additionFieldsPlainText: String) -> ([String: String], [String]){
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
    
    func getPlainText() -> String {
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
     
     Example of TOTP fields
     otp_secret: secretsecretsecretsecretsecretsecret
     otp_type: totp
     otp_algorithm: sha1
     otp_period: 30
     otp_digits: 6
     
     Example of HOTP fields
     otp_secret: secretsecretsecretsecretsecretsecret
     otp_type: hotp
     otp_counter: 1
     otp_digits: 6
     
     */
    func updateOtpToken() {
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
        
        // get algorithm
        var algorithm = Generator.Algorithm.sha1
        if let algoString = getAdditionValue(withKey: "otp_algorithm") {
            switch algoString.lowercased() {
                case "sha1":
                    algorithm = Generator.Algorithm.sha1
                case "sha256":
                    algorithm = Generator.Algorithm.sha256
                case "sha512":
                    algorithm = Generator.Algorithm.sha512
                default:
                    algorithm = Generator.Algorithm.sha1
            }
        }
    
        // construct the token
        if type == "totp" {
            if let digits = Int(getAdditionValue(withKey: "otp_digits") ?? ""),
                let period = Double(getAdditionValue(withKey: "otp_period") ?? "") {
                guard let generator = Generator(
                    factor: .timer(period: period),
                    secret: secretData,
                    algorithm: algorithm,
                    digits: digits) else {
                        print("Invalid generator parameters \(self.plainText)")
                        return
                }
                self.otpType = "totp"
                self.otpToken = Token(name: self.name, issuer: "", generator: generator)
            }
        } else {
            print("We do not support HOTP currently.")
        }
    }
}
