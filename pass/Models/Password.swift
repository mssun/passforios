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
    var username = ""
    var password = ""
    var url = ""
    var additions = [AdditionField]()
    
    init() { }
    
    convenience init(name: String, username: String, password: String, additions: [AdditionField]) {
        self.init(name: name, username: username, password: password, url: "", additions: additions)
    }
    
    init(name: String, username: String, password: String, url: String, additions: [AdditionField]) {
        self.name = name
        self.username = username
        self.password = password
        self.url = url
        self.additions = additions
    }
}

extension PasswordEntity {
    func decrypt() throws -> Password? {
        var password: Password?
        let encryptedDataPath = URL(fileURLWithPath: "\(Globals.repositoryPath)/\(rawPath!)")
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
    
    func encrypt(password: Password) throws -> Data {
        name = password.name
        rawPath = ""
        let plainPassword = password.password
//        let plainAdditions = password.additions.map { "\($0.title): \($0.content)" }.joined(separator: "\n")
        let plainData = "\(plainPassword)\n".data(using: .ascii)!
        let pgp = PasswordStore.shared.pgp
        let encryptedData = try pgp.encryptData(plainData, usingPublicKey: pgp.getKeysOf(.public)[0], armored: false)
        return encryptedData
    }
}
