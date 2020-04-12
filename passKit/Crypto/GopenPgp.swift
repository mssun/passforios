//
//  GopenPgp.swift
//  passKit
//
//  Created by Danny Moesch on 08.09.19.
//  Copyright © 2019 Bob Sun. All rights reserved.
//

import Crypto

struct GopenPgp: PgpInterface {

    private static let errorMapping: [String: Error] = [
        "gopenpgp: error in unlocking key: openpgp: invalid data: private key checksum failure":  AppError.WrongPassphrase,
        "openpgp: incorrect key":                               AppError.KeyExpiredOrIncompatible,
    ]

    private let publicKey: CryptoKey
    private let privateKey: CryptoKey

    init(publicArmoredKey: String, privateArmoredKey: String) throws {
        var error: NSError?
        guard let publicKey = CryptoNewKeyFromArmored(publicArmoredKey, &error),
              let privateKey = CryptoNewKeyFromArmored(privateArmoredKey, &error) else {
            guard error == nil else {
                throw error!
            }
            throw AppError.KeyImport
        }
        self.publicKey = publicKey
        self.privateKey = privateKey
    }

    func decrypt(encryptedData: Data, keyID: String, passphrase: String) throws -> Data? {
        do {
            let unlockedKey = try privateKey.unlock(passphrase.data(using: .utf8))
            var error: NSError?

            guard let keyRing = CryptoNewKeyRing(unlockedKey, &error) else {
                guard error == nil else {
                    throw error!
                }
                throw AppError.Decryption
            }

            let message = createPgpMessage(from: encryptedData)
            return try keyRing.decrypt(message, verifyKey: nil, verifyTime: 0).data
        } catch {
            throw Self.errorMapping[error.localizedDescription, default: error]
        }
    }

    func encrypt(plainData: Data, keyID: String) throws -> Data {
        var error: NSError?

        guard let keyRing = CryptoNewKeyRing(publicKey, &error) else {
            guard error == nil else {
                throw error!
            }
            throw AppError.Encryption
        }

        let encryptedData = try keyRing.encrypt(CryptoNewPlainMessage(plainData.mutable as Data), privateKey: nil)
        if Defaults.encryptInArmored {
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
        let fingerprint = publicKey.getHexKeyID()
        return String(fingerprint).uppercased()
    }

    var shortKeyId: String {
        var error: NSError?
        let fingerprint = publicKey.getHexKeyID()
        return String(fingerprint.suffix(8)).uppercased()
    }

    private func createPgpMessage(from encryptedData: Data) -> CryptoPGPMessage? {
        // Important note:
        // Even if Defaults.encryptInArmored is true now, it could be different during the encryption.
        var error: NSError?
        let message = CryptoNewPGPMessageFromArmored(String(data: encryptedData, encoding: .ascii), &error)
        if error == nil {
            return message
        }
        return CryptoNewPGPMessage(encryptedData.mutable as Data)
    }
}
