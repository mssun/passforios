//
//  PasswordGeneratorFlavour.swift
//  passKit
//
//  Created by Danny Moesch on 28.11.18.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

import KeychainAccess

public enum PasswordGeneratorFlavor: String {
    case apple = "Apple"
    case random = "Random"
    case xkcd = "XKCD"

    public var localized: String {
        return rawValue.localize()
    }
    
    public var longNameLocalized: String {
        switch self {
        case .apple:
            return "ApplesKeychainStyle".localize()
        case .random:
            return "RandomString".localize()
        case .xkcd:
            return "XKCDStyle".localize()
        }
    }

    public var defaultLength: (min: Int, max: Int, def: Int) {
        switch self {
        case .apple:
            return (15, 15, 15)
        case .random:
            return (4, 64, 16)
        case .xkcd:
            return (2, 5, 3)
        }
    }

    public func generate(length: Int) -> String {
        switch self {
        case .apple:
            return Keychain.generatePassword()
        case .random:
            return PasswordGeneratorFlavor.generateRandom(length: length)
        case .xkcd:
            return PasswordGeneratorFlavor.generateXKCD(length: length)
        }
    }

    private static func generateRandom(length: Int) -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*_+-="
        return String((0..<length).map { _ in chars.randomElement()! })
    }
    
    private static func generateXKCD(length: Int) -> String {
        // Get the word list
        let bundle = Bundle(identifier: Globals.passKitBundleIdentifier)!
        let wordlistNames = [
            "eff_long_wordlist",
            "eff_short_wordlist"
        ]
        let data = wordlistNames.map{ name -> String in
            guard let asset = NSDataAsset(name: name, bundle: bundle),
                let data = String(data: asset.data, encoding: .utf8) else {
                    return ""
            }
            return data
        }
        let words = data.joined(separator: "\n").splitByNewline()
        
        // Generate a password
        let delimiters = "0123456789!@#$%^&*_+-="
        var password = ""
        (0..<length).forEach { _ in
            var word = words.randomElement()!
            if Bool.random() {
                word = word.uppercased()
            }
            password += word + String(delimiters.randomElement()!)
        }
        return password
    }
}

extension PasswordGeneratorFlavor: CaseIterable {}
