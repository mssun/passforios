//
//  ObjectivePgp.swift
//  passKit
//
//  Created by Danny Moesch on 08.09.19.
//  Copyright © 2019 Bob Sun. All rights reserved.
//

import ObjectivePGP

struct ObjectivePgp: PgpInterface {

    private let publicKey: Key
    private let privateKey: Key

    private let keyring = ObjectivePGP.defaultKeyring

    init(publicArmoredKey: String, privateArmoredKey: String) throws {
        guard let publicKeyData = publicArmoredKey.data(using: .ascii), let privateKeyData = privateArmoredKey.data(using: .ascii) else {
            throw AppError.KeyImport
        }
        let publicKeys = try ObjectivePGP.readKeys(from: publicKeyData)
        let privateKeys = try ObjectivePGP.readKeys(from: privateKeyData)
        keyring.import(keys: publicKeys)
        keyring.import(keys: privateKeys)
        guard let publicKey = publicKeys.first, let privateKey = privateKeys.first else {
            throw AppError.KeyImport
        }
        self.publicKey = publicKey
        self.privateKey = privateKey
    }

    func decrypt(encryptedData: Data, keyID: String, passphrase: String) throws -> Data? {
        return try ObjectivePGP.decrypt(encryptedData, andVerifySignature: false, using: keyring.keys) { _ in passphrase }
    }

    func encrypt(plainData: Data, keyID: String) throws -> Data {
        let encryptedData = try ObjectivePGP.encrypt(plainData, addSignature: false, using: keyring.keys, passphraseForKey: nil)
        if Defaults.encryptInArmored {
            return Armor.armored(encryptedData, as: .message).data(using: .ascii)!
        }
        return encryptedData
    }

    var keyId: String {
        return publicKey.keyID.longIdentifier
    }

    var shortKeyId: String {
        return publicKey.keyID.shortIdentifier
    }
}
