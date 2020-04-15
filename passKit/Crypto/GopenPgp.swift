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

    private var publicKeys: [String: CryptoKey] = [:]
    private var privateKeys: [String: CryptoKey] = [:]

    init(publicArmoredKey: String, privateArmoredKey: String) throws {
        let pubKeys = extractKeysFromArmored(str: publicArmoredKey)
        let prvKeys = extractKeysFromArmored(str: privateArmoredKey)

        for key in pubKeys {
            var error: NSError?
            guard let k = CryptoNewKeyFromArmored(key, &error) else {
                guard error == nil else {
                    throw error!
                }
                throw AppError.KeyImport
            }
            publicKeys[k.getFingerprint().lowercased()] = k
        }

        for key in prvKeys {
            var error: NSError?
            guard let k = CryptoNewKeyFromArmored(key, &error) else {
                guard error == nil else {
                    throw error!
                }
                throw AppError.KeyImport
            }
            privateKeys[k.getFingerprint().lowercased()] = k
        }

    }

    func extractKeysFromArmored(str: String) -> [String] {
         var keys: [String] = []
         var key: String = ""
         for line in str.splitByNewline() {
             if line.trimmed.uppercased().hasPrefix("-----BEGIN PGP") {
                 key = ""
                 key += line
             } else if line.trimmed.uppercased().hasPrefix("-----END PGP") {
                 key += line
                 keys.append(key)
             } else {
                 key += line
             }
            key += "\n"
         }
         return keys
     }

    func containsPublicKey(with keyID: String) -> Bool {
        publicKeys.keys.contains(where: { key in key.hasSuffix(keyID.lowercased()) })
    }

    func containsPrivateKey(with keyID: String) -> Bool {
        privateKeys.keys.contains(where: { key in key.hasSuffix(keyID.lowercased()) })
    }

    func decrypt(encryptedData: Data, keyID: String, passphrase: String) throws -> Data? {
        guard let e = privateKeys.first(where: { (key, _) in key.hasSuffix(keyID.lowercased()) }),
            let privateKey = privateKeys[e.key] else {
            throw AppError.Decryption
        }

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
        guard let e = publicKeys.first(where: { (key, _) in key.hasSuffix(keyID.lowercased()) }),
            let publicKey = publicKeys[e.key] else {
            throw AppError.Encryption
        }

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

    var keyID: [String] {
        return  publicKeys.keys.map({ $0.uppercased() })
    }

    var shortKeyID: [String] {
        return publicKeys.keys.map({ $0.suffix(8).uppercased()})
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
