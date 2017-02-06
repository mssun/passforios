//
//  Password.swift
//  pass
//
//  Created by Mingshen Sun on 2/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import SwiftyUserDefaults

class Password {
    var name: String
    var password: String
    var additions: [String: String]
    
    init() {
        name = ""
        password = ""
        additions = [:]
    }
    
    init(name: String, password: String, additions: [String: String]) {
        self.name = name
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
        var decrypted_addtions = [String: String]()
        plain.enumerateLines(invoking: { line, _ in
            let items = line.characters.split(separator: ":").map(String.init)
            if items.count == 1 {
                decrypted_password = items[0]
            } else {
                let key = items[0]
                let value = items[1].trimmingCharacters(in: .whitespaces)
                decrypted_addtions[key] = value
            }
        })
        password = Password(name: name!, password: decrypted_password, additions: decrypted_addtions)
        return password
    }
}
