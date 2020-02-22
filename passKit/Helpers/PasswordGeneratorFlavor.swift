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

    public var localized: String {
        return rawValue.localize()
    }
    
    public var longNameLocalized: String {
        switch self {
        case .apple:
            return "ApplesKeychainStyle".localize()
        case .random:
            return "RandomString".localize()
        }
    }

    public var defaultLength: (min: Int, max: Int, def: Int) {
        switch self {
        case .apple:
            return (15, 15, 15)
        case .random:
            return (4, 64, 16)
        }
    }

    public func generate(length: Int) -> String {
        switch self {
        case .apple:
            return Keychain.generatePassword()
        case .random:
            return PasswordGeneratorFlavor.generateRandom(length: length)
        }
    }

    private static func generateRandom(length: Int) -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*_+-="
        return String((0..<length).map { _ in chars.randomElement()! })
    }
}

extension PasswordGeneratorFlavor: CaseIterable {}
