//
//  ObjectivePGPInterface.swift
//  passKit
//
//  Created by Danny Moesch on 08.09.19.
//  Copyright © 2019 Bob Sun. All rights reserved.
//

import ObjectivePGP

struct ObjectivePGPInterface: PGPInterface {
    private let keyring = ObjectivePGP.defaultKeyring

    init(publicArmoredKey: String, privateArmoredKey: String) throws {
        guard let publicKeyData = publicArmoredKey.data(using: .ascii), let privateKeyData = privateArmoredKey.data(using: .ascii) else {
            throw AppError.keyImport
        }
        let publicKeys = try catchingObjectiveCException(orThrow: .keyImport) { try ObjectivePGP.readKeys(from: publicKeyData) }
        let privateKeys = try catchingObjectiveCException(orThrow: .keyImport) { try ObjectivePGP.readKeys(from: privateKeyData) }
        keyring.import(keys: publicKeys)
        keyring.import(keys: privateKeys)
        guard publicKeys.first != nil, privateKeys.first != nil else {
            throw AppError.keyImport
        }
    }

    func decrypt(encryptedData: Data, keyID _: String?, passphrase: String) throws -> Data? {
        try catchingObjectiveCException(orThrow: .decryption) {
            try ObjectivePGP.decrypt(encryptedData, andVerifySignature: false, using: keyring.keys) { _ in passphrase }
        }
    }

    func encrypt(plainData: Data, keyID _: String?) throws -> Data {
        try catchingObjectiveCException(orThrow: .encryption) {
            let encryptedData = try ObjectivePGP.encrypt(plainData, addSignature: false, using: keyring.keys, passphraseForKey: nil)
            if Defaults.encryptInArmored {
                return Armor.armored(encryptedData, as: .message).data(using: .ascii)!
            }
            return encryptedData
        }
    }

    func containsPublicKey(with keyID: String) -> Bool {
        keyring.findKey(keyID)?.isPublic ?? false
    }

    func containsPrivateKey(with keyID: String) -> Bool {
        keyring.findKey(keyID)?.isSecret ?? false
    }

    var keyID: [String] {
        keyring.keys.map(\.keyID.longIdentifier)
    }

    var shortKeyID: [String] {
        keyring.keys.map(\.keyID.shortIdentifier)
    }
}

/// Runs a block which may raise an Objective-C exception, e.g. when ObjectivePGP is fed a malformed
/// key. Such an exception cannot be caught in Swift and terminates the app, so it is replaced by the
/// given error here.
private func catchingObjectiveCException<T>(orThrow appError: AppError, _ block: () throws -> T) throws -> T {
    var result: Result<T, Error>?
    do {
        try ObjectiveCExceptionCatcher.catchException {
            result = Result { try block() }
        }
    } catch {
        throw appError
    }
    guard let result else {
        throw appError
    }
    return try result.get()
}
