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
    var name = ""
    var password = ""
    var additions: [String: String]?
    
    init(name: String, password: String, additions: [String: String]?) {
        self.name = name
        self.password = password
        self.additions = additions
    }
}

extension PasswordEntity {
    func decrypt() -> Password? {
        var password: Password?
        let encryptedDataPath = URL(fileURLWithPath: "\(Globals.shared.documentPath)/\(rawPath!)")
        do {
            let encryptedData = try Data(contentsOf: encryptedDataPath)
            let decryptedData = try PasswordStore.shared.pgp.decryptData(encryptedData, passphrase: Defaults[.pgpKeyPassphrase])
            let plain = String(data: decryptedData, encoding: .ascii) ?? ""
            password = Password(name: name!, password: plain, additions: nil)
        }  catch let error as NSError {
            print(error.debugDescription)
        }
        return password
    }
}
