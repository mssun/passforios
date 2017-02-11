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
    
    convenience init(name: String, plainText: String) {
        var i = 0
        var additionFieldsArray = [AdditionField]()
        var password  = ""
        var unkownIndex = 0
        plainText.enumerateLines() { line, _ in
            if i == 0 {
                password = line
            } else {
                let items = line.characters.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)
                var key = ""
                var value = ""
                if items.count == 1 {
                    unkownIndex += 1
                    key = "unkown \(unkownIndex)"
                    value = items[0]
                } else {
                    key = items[0]
                    value = items[1].trimmingCharacters(in: .whitespaces)
                }
                additionFieldsArray.append(AdditionField(title: key, content: value))
            }
            i += 1
        }
        self.init(name: name, password: password, additionsArray: additionFieldsArray)
    }
    
    init(name: String, password: String, additionsArray: [AdditionField]) {
        self.name = name
        self.password = password
        for additionField in additionsArray {
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
    
    func getPlainText() -> String {
        let plainAdditionsText = self.additionKeys.map { "\($0): \(self.additions[$0]!)" }.joined(separator: "\n")
        return "\(self.password)\n\(plainAdditionsText)"
    }
    
    func getPlainData() -> Data {
        return getPlainText().data(using: .ascii)!
    }
    
    private func getAdditionValue(withKey key: String) -> String? {
        return self.additions[key]
    }
    
}

extension PasswordEntity {
    func decrypt() throws -> Password? {
        var password: Password?
        let encryptedDataPath = URL(fileURLWithPath: "\(Globals.repositoryPath)/\(rawPath!)")
        let encryptedData = try Data(contentsOf: encryptedDataPath)
        let decryptedData = try PasswordStore.shared.pgp.decryptData(encryptedData, passphrase: Defaults[.pgpKeyPassphrase])
        let plainText = String(data: decryptedData, encoding: .ascii) ?? ""
        password = Password(name: name!, plainText: plainText)
        return password
    }
    
    func encrypt(password: Password) throws -> Data {
        name = password.name
        rawPath = ""
        let plainData = password.getPlainData()
        let pgp = PasswordStore.shared.pgp
        let encryptedData = try pgp.encryptData(plainData, usingPublicKey: pgp.getKeysOf(.public)[0], armored: false)
        return encryptedData
    }
}
