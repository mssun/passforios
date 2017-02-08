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
    var name: String
    var username: String
    var password: String
    var additions: [AdditionField]
    
    init() {
        name = ""
        password = ""
        username = ""
        additions = []
    }
    
    init(name: String, username: String, password: String, additions: [AdditionField]) {
        self.name = name
        self.username = username
        self.password = password
        self.additions = additions
    }
}

extension PasswordEntity {
    func decrypt() throws -> Password? {
        var password: Password?
        let encryptedDataPath = URL(fileURLWithPath: "\(Globals.documentPath)/\(rawPath!)")
        let encryptedData = try Data(contentsOf: encryptedDataPath)
        let decryptedData = try PasswordStore.shared.pgp.decryptData(encryptedData, passphrase: Defaults[.pgpKeyPassphrase])
        let plain = String(data: decryptedData, encoding: .ascii) ?? ""
        var decrypted_password = ""
        var username = ""
        var decrypted_addtions = [AdditionField]()
        var i = 0
        plain.enumerateLines(invoking: { line, _ in
            if i == 0 {
                decrypted_password = line
            } else {
                let items = line.characters.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)
                if items.count == 2 && items[0].lowercased() == "username"  {
                    username = items[1].trimmingCharacters(in: .whitespaces)
                } else {
                    var key = ""
                    var value = ""
                    if items.count == 1 {
                        key = "unknown"
                        value = items[0]
                    } else {
                        key = items[0]
                        value = items[1].trimmingCharacters(in: .whitespaces)
                    }
                    decrypted_addtions.append(AdditionField(title: key, content: value))
                }
            }
            i += 1
        })
        password = Password(name: name!, username: username, password: decrypted_password, additions: decrypted_addtions)
        return password
    }
}
