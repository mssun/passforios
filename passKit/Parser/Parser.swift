//
//  Parser.swift
//  passKit
//
//  Created by Danny Moesch on 16.08.18.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

class Parser {
    let firstLine: String
    let additionsSection: String
    let purgedAdditionalLines: [String]

    // The parsing process is expensive. This field makes sure it is only done once if actually needed.
    private(set) lazy var additionFields = getAdditionFields()

    init(plainText: String) {
        let splittedPlainText = plainText.splitByNewline()

        firstLine = splittedPlainText.first!
        self.additionsSection = splittedPlainText[1...].joined(separator: "\n")
        self.purgedAdditionalLines = splittedPlainText[1...].filter { !$0.isEmpty }
    }

    private func getAdditionFields() -> [AdditionField] {
        var additions: [AdditionField] = []
        var unknownIndex: UInt = 0
        var i = purgedAdditionalLines.startIndex
        while i < purgedAdditionalLines.count {
            let line = purgedAdditionalLines[i]
            i += 1
            var (key, value) = Parser.getKeyValuePair(from: line)
            if key == nil {
                unknownIndex += 1
                key = Constants.unknown(unknownIndex)
            } else if value == Constants.MULTILINE_WITH_LINE_BREAK_INDICATOR {
                value = gatherMultilineValue(startingAt: &i, removingLineBreaks: false)
            } else if value == Constants.MULTILINE_WITHOUT_LINE_BREAK_INDICATOR {
                value = gatherMultilineValue(startingAt: &i, removingLineBreaks: true)
            }
            additions.append(key! => value)
        }
        return additions
    }

    private func gatherMultilineValue(startingAt i: inout Int, removingLineBreaks: Bool) -> String {
        var result = ""
        guard i < purgedAdditionalLines.count else {
            return result
        }
        let numberInitialBlanks = purgedAdditionalLines[i].enumerated().first {
            $1 != Character(Constants.BLANK)
        }?.0 ?? purgedAdditionalLines[i].count
        guard numberInitialBlanks != 0 else {
            return result
        }
        let initialBlanks = String(repeating: Constants.BLANK, count: numberInitialBlanks)

        while i < purgedAdditionalLines.count, purgedAdditionalLines[i].starts(with: initialBlanks) {
            result.append(String(purgedAdditionalLines[i].dropFirst(numberInitialBlanks)))
            result.append(Constants.getSeparator(breakingLines: !removingLineBreaks))
            i += 1
        }
        return result.trimmed
    }

    /// Split line from password file in to a key-value pair separted by `: `.
    ///
    /// - Parameter line: Line from a password file
    /// - Returns: Pair of two `String`s of which the first one can be 'nil'
    static func getKeyValuePair(from line: String) -> (key: String?, value: String) {
        let items = line.components(separatedBy: ": ").map { String($0).trimmingCharacters(in: .whitespaces) }
        var key: String?
        var value = ""
        if items.count == 1 || (items[0].isEmpty && items[1].isEmpty) {
            // No ': ' found, or empty on both sides of ': '.
            value = line
            // "otpauth" special case
            if value.hasPrefix(Constants.OTPAUTH_URL_START) {
                key = Constants.OTPAUTH
            }
        } else {
            if !items[0].isEmpty {
                key = items[0]
            }
            value = items[1]
        }
        return (key, value)
    }
}
