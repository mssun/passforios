//
//  PasswordGenerator.swift
//  passKit
//
//  Created by Danny Moesch on 27.02.20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

public struct PasswordGenerator: Codable {
    private static let digits = "0123456789"
    private static let letters = "abcdefghijklmnopqrstuvwxyz"
    private static let capitalLetters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    private static let specialSymbols = "!\"#$%&'()*+,./:;<=>?@[\\]^_`{|}~"

    private static let words: [String] = {
        let bundle = Bundle(identifier: Globals.passKitBundleIdentifier)!
        return ["eff_long_wordlist", "eff_short_wordlist"]
            .map { name -> String in
                guard let asset = NSDataAsset(name: name, bundle: bundle),
                      let data = String(data: asset.data, encoding: .utf8) else {
                    return ""
                }
                return data
            }
            .joined(separator: "\n")
            .splitByNewline()
    }()

    public var flavor = PasswordGeneratorFlavor.random
    public var length = 15
    public var varyCases = true
    public var useDigits = true
    public var useSpecialSymbols = true
    public var groups = 4

    public var limitedLength: Int {
        let lengthLimits = flavor.lengthLimits
        return max(lengthLimits.min, min(lengthLimits.max, length))
    }

    private var characters: String {
        var characters = Self.letters
        if varyCases {
            characters.append(Self.capitalLetters)
        }
        if useDigits {
            characters.append(Self.digits)
        }
        if useSpecialSymbols {
            characters.append(Self.specialSymbols)
        }
        return characters
    }

    private var delimiters: String {
        var delimiters = ""
        if useDigits {
            delimiters.append(Self.digits)
        }
        if useSpecialSymbols {
            delimiters.append(Self.specialSymbols)
        }
        return delimiters
    }

    public func generate() -> String {
        switch flavor {
        case .random:
            return generateRandom()
        case .xkcd:
            return generateXkcd()
        }
    }

    public func isAcceptable(groups: Int) -> Bool {
        guard flavor == .random, groups > 0, groups < length else {
            return false
        }
        return (length + 1).isMultiple(of: groups)
    }

    private func generateRandom() -> String {
        let currentCharacters = characters
        if groups > 1, isAcceptable(groups: groups) {
            return selectRandomly(count: limitedLength - groups + 1, from: currentCharacters)
                .slices(count: UInt(groups))
                .map { String($0) }
                .joined(separator: "-")
        }
        return String(selectRandomly(count: limitedLength, from: currentCharacters))
    }

    private func generateXkcd() -> String {
        let currentDelimiters = delimiters
        return getRandomDelimiter(from: currentDelimiters) + (0 ..< limitedLength)
            .map { _ in getRandomWord() + getRandomDelimiter(from: currentDelimiters) }
            .joined()
    }

    private func getRandomDelimiter(from delimiters: String) -> String {
        if delimiters.isEmpty {
            return ""
        }
        return String(delimiters.randomElement()!)
    }

    private func getRandomWord() -> String {
        let word = Self.words.randomElement()!
        if varyCases, Bool.random() {
            return word.uppercased()
        }
        return word
    }

    private func selectRandomly(count: Int, from string: String) -> [Character] {
        (0 ..< count).map { _ in string.randomElement()! }
    }
}

extension PasswordGeneratorFlavor: Codable {}
