//
//  PasswordGeneratorFlavour.swift
//  passKit
//
//  Created by Danny Moesch on 28.11.18.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

import KeychainAccess

public enum PasswordGeneratorFlavour: String {
    case APPLE = "Apple"
    case RANDOM = "Random"

    private static let ALLOWED_CHARACTERS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*_+-="

    public static func from(_ option: String) -> PasswordGeneratorFlavour {
        return PasswordGeneratorFlavour(rawValue: option) ?? PasswordGeneratorFlavour.RANDOM
    }

    public var name: String {
        return rawValue.localize()
    }

    public var defaultLength: (min: Int, max: Int, def: Int) {
        switch self {
        case .APPLE:
            return (15, 15, 15)
        default:
            return (4, 64, 16)
        }
    }

    public func generatePassword(length: Int) -> String {
        switch self {
        case .APPLE:
            return Keychain.generatePassword()
        default:
            return PasswordGeneratorFlavour.randomString(length: length)
        }
    }

    private static func randomString(length: Int) -> String {
        return String((0..<length).map { _ in ALLOWED_CHARACTERS.randomElement()! })
    }
}

extension PasswordGeneratorFlavour: CaseIterable {}
