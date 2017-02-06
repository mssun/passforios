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
        let encryptedDataPath = URL(fileURLWithPath: "\(Globals.shared.documentPath)/\(rawPath!)")
        let encryptedData = try Data(contentsOf: encryptedDataPath)
        let decryptedData = try PasswordStore.shared.pgp.decryptData(encryptedData, passphrase: Defaults[.pgpKeyPassphrase])
        let plain = String(data: decryptedData, encoding: .ascii) ?? ""
        var decrypted_password = ""
        var username = ""
        var decrypted_addtions = [AdditionField]()
        plain.enumerateLines(invoking: { line, _ in
            let items = line.characters.split(separator: ":").map(String.init)
            if items.count == 1 {
                decrypted_password = items[0]
            } else {
                let key = items[0]
                let value = items[1].trimmingCharacters(in: .whitespaces)
                if key.lowercased() == "username" {
                    username = value
                } else {
                    decrypted_addtions.append(AdditionField(title: key, content: value))
                }
            }
        })
        password = Password(name: name!, username: username, password: decrypted_password, additions: decrypted_addtions)
        return password
    }
}
