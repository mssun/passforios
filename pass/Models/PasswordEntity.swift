//
//  PasswordEntity.swift
//  pass
//
//  Created by Mingshen Sun on 11/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import SwiftyUserDefaults

extension PasswordEntity {
    func decrypt(passphrase: String) throws -> Password? {
        var password: Password?
        let encryptedDataPath = URL(fileURLWithPath: "\(Globals.repositoryPath)/\(rawPath!)")
        let encryptedData = try Data(contentsOf: encryptedDataPath)
        let decryptedData = try PasswordStore.shared.pgp.decryptData(encryptedData, passphrase: passphrase)
        let plainText = String(data: decryptedData, encoding: .ascii) ?? ""
        password = Password(name: name!, plainText: plainText)
        return password
    }
    
    func encrypt(password: Password) throws -> Data {
        name = password.name
        let plainData = password.getPlainData()
        let pgp = PasswordStore.shared.pgp
        let encryptedData = try pgp.encryptData(plainData, usingPublicKey: pgp.getKeysOf(.public)[0], armored: false)
        return encryptedData
    }
}
