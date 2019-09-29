//
//  GopenPgp.swift
//  passKit
//
//  Created by Danny Moesch on 08.09.19.
//  Copyright © 2019 Bob Sun. All rights reserved.
//

import Crypto

struct GopenPgp: PgpInterface {

    private let publicKey: CryptoKeyRing
    private let privateKey: CryptoKeyRing

    init(publicArmoredKey: String, privateArmoredKey: String) throws {
        guard let pgp = CryptoGetGopenPGP() else {
            throw AppError.KeyImport
        }
        publicKey = try pgp.buildKeyRingArmored(publicArmoredKey)
        privateKey = try pgp.buildKeyRingArmored(privateArmoredKey)
    }

    func decrypt(encryptedData: Data, passphrase: String) throws -> Data? {
        try privateKey.unlock(withPassphrase: passphrase)
        let message = createPgpMessage(from: encryptedData)
        return try privateKey.decrypt(message, verifyKey: nil, verifyTime: 0).data
    }

    func encrypt(plainData: Data) throws -> Data {
        let encryptedData = try publicKey.encrypt(CryptoNewPlainMessage(plainData.mutable as Data), privateKey: nil)
        if SharedDefaults[.encryptInArmored] {
            var error: NSError?
            let armor = encryptedData.getArmored(&error)
            guard error == nil else {
                throw error!
            }
            return armor.data(using: .ascii)!
        }
        return encryptedData.getBinary()!
    }

    var keyId: String {
        var error: NSError?
        let fingerprint = publicKey.getFingerprint(&error)
        return error == nil ? String(fingerprint.suffix(8)).uppercased() : ""
    }

    private func createPgpMessage(from encryptedData: Data) -> CryptoPGPMessage? {
        // Important note:
        // Even if SharedDefaults[.encryptInArmored] is true now, it could be different during the encryption.
        var error: NSError?
        let message = CryptoNewPGPMessageFromArmored(String(data: encryptedData, encoding: .ascii), &error)
        if error == nil {
            return message
        }
        return CryptoNewPGPMessage(encryptedData.mutable as Data)
    }
}
