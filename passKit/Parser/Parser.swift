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

        self.firstLine = splittedPlainText.first!
        self.additionsSection = splittedPlainText[1...].joined(separator: "\n")
        self.purgedAdditionalLines = splittedPlainText[1...].filter { !$0.isEmpty }
    }

    private func getAdditionFields() -> [AdditionField] {
        var additions: [AdditionField] = []
        var unknownIndex: UInt = 0
        var lineNumber = purgedAdditionalLines.startIndex
        while lineNumber < purgedAdditionalLines.count {
            let line = purgedAdditionalLines[lineNumber]
            lineNumber += 1
            var (key, value) = Self.getKeyValuePair(from: line)
            if key == nil {
                unknownIndex += 1
                key = Constants.unknown(unknownIndex)
            } else if value == Constants.MULTILINE_WITH_LINE_BREAK_INDICATOR {
                value = gatherMultilineValue(startingAt: &lineNumber, removingLineBreaks: false)
            } else if value == Constants.MULTILINE_WITHOUT_LINE_BREAK_INDICATOR {
                value = gatherMultilineValue(startingAt: &lineNumber, removingLineBreaks: true)
            }
            additions.append(key! => value)
        }
        return additions
    }

    private func gatherMultilineValue(startingAt lineNumber: inout Int, removingLineBreaks: Bool) -> String {
        var result = ""
        guard lineNumber < purgedAdditionalLines.count else {
            return result
        }
        // swiftlint:disable:next unused_enumerated
        let numberInitialBlanks = purgedAdditionalLines[lineNumber].enumerated().first {
            $1 != Character(Constants.BLANK)
        }?.0 ?? purgedAdditionalLines[lineNumber].count
        guard numberInitialBlanks != 0 else {
            return result
        }
        let initialBlanks = String(repeating: Constants.BLANK, count: numberInitialBlanks)

        while lineNumber < purgedAdditionalLines.count, purgedAdditionalLines[lineNumber].starts(with: initialBlanks) {
            result.append(String(purgedAdditionalLines[lineNumber].dropFirst(numberInitialBlanks)))
            result.append(Constants.getSeparator(breakingLines: !removingLineBreaks))
            lineNumber += 1
        }
        return result.trimmed
    }

    /// Split line from password file in to a key-value pair separted by `:`.
    ///
    /// - Parameter line: Line from a password file
    /// - Returns: Pair of two `String`s of which the first one can be 'nil'. Both strings are already trimmed from whitespaces.
    static func getKeyValuePair(from line: String) -> (key: String?, value: String) {
        if let separatorIdx = line.firstIndex(of: ":") {
            let key = String(line[..<separatorIdx]).trimmingCharacters(in: .whitespaces)
            return (key.isEmpty ? nil : key, String(line[line.index(after: separatorIdx)...]).trimmingCharacters(in: .whitespaces))
        }
        return (nil, line.trimmingCharacters(in: .whitespaces))
    }
}
