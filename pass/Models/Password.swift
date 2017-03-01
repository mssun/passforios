//
//  Password.swift
//  pass
//
//  Created by Mingshen Sun on 2/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import SwiftyUserDefaults

struct AdditionField {
    var title: String
    var content: String
}

class Password {
    var name = ""
    var password = ""
    var additions = [String: String]()
    var additionKeys = [String]()
    var plainText = ""
    var changed = false
    
    init(name: String, plainText: String) {
        let plainTextSplit = plainText.characters.split(maxSplits: 1, omittingEmptySubsequences: false) {
            $0 == "\n" || $0 == "\r\n"
        }.map(String.init)
        let password  = plainTextSplit[0]
        let additionFieldsArray = Password.getAdditionFields(from: plainTextSplit[1])
        self.name = name
        self.password = password
        self.plainText = plainText
        for additionField in additionFieldsArray {
            self.additions[additionField.title] = additionField.content
            self.additionKeys.append(additionField.title)
        }
    }
    
    func getUsername() -> String? {
        return getAdditionValue(withKey: "Username") ?? getAdditionValue(withKey: "username")
    }
    
    func getURL() -> String? {
        return getAdditionValue(withKey: "URL") ?? getAdditionValue(withKey: "url") ?? getAdditionValue(withKey: "Url")
    }
    
    static func getAdditionFields(from additionFieldsPlainText: String) -> [AdditionField]{
        var additionFieldsArray = [AdditionField]()
        var unknownIndex = 0

        additionFieldsPlainText.enumerateLines() { line, _ in
            if line == "" {
                return
            }
            let items = line.characters.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)
            var key = ""
            var value = ""
            if items.count == 1 {
                unknownIndex += 1
                key = "unknown \(unknownIndex)"
                value = items[0]
            } else if items.count == 2 {
                key = items[0]
                value = items[1].trimmingCharacters(in: .whitespaces)
            }
            additionFieldsArray.append(AdditionField(title: key, content: value))
        }
        return additionFieldsArray
    }
    
    func updatePassword(name: String, plainText: String) {
        self.name = name
        if self.plainText != plainText {
            let plainTextSplit = plainText.characters.split(maxSplits: 1, omittingEmptySubsequences: false) {
                $0 == "\n" || $0 == "\r\n"
                }.map(String.init)
            let password  = plainTextSplit[0]
            let additionFieldsArray = Password.getAdditionFields(from: plainTextSplit[1])
            self.password = password
            self.additions = [String: String]()
            self.additionKeys = []
            for additionField in additionFieldsArray {
                self.additions[additionField.title] = additionField.content
                self.additionKeys.append(additionField.title)
            }
            changed = true
        }
    }
    
    func getAdditionsPlainText() -> String {
        let plainAdditionsText = self.additionKeys.map {
            if $0.hasPrefix("unknown") {
                return "\(self.additions[$0]!)"
            } else {
                return "\($0): \(self.additions[$0]!)"
            }
        }.joined(separator: "\n")
        return plainAdditionsText
    }
    
    func getPlainText() -> String {
        return "\(self.password)\n\(getAdditionsPlainText())"
    }
    
    func getPlainData() -> Data {
        return getPlainText().data(using: .utf8)!
    }
    
    private func getAdditionValue(withKey key: String) -> String? {
        return self.additions[key]
    }
    
}
