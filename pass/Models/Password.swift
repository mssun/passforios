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
        self.name = name
        self.plainText = plainText
        
        // get password and additional fields
        let plainTextSplit = plainText.characters.split(maxSplits: 1, omittingEmptySubsequences: false) {
            $0 == "\n" || $0 == "\r\n"
            }.map(String.init)
        self.password  = plainTextSplit[0]
        (self.additions, self.additionKeys) = Password.getAdditionFields(from: plainTextSplit[1])
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
    
    func updatePassword(name: String, plainText: String) {
        self.name = name
        if self.plainText != plainText {
            self.name = name
            self.plainText = plainText
            
            // get password and additional fields
            let plainTextSplit = plainText.characters.split(maxSplits: 1, omittingEmptySubsequences: false) {
                $0 == "\n" || $0 == "\r\n"
                }.map(String.init)
            self.password  = plainTextSplit[0]
            (self.additions, self.additionKeys) = Password.getAdditionFields(from: plainTextSplit[1])
            
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
