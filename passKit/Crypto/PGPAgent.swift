//
//  PGPAgent.swift
//  passKit
//
//  Created by Yishi Lin on 2019/7/17.
//  Copyright © 2019 Bob Sun. All rights reserved.
//

public class PGPAgent {
    public static let shared = PGPAgent()

    private let keyStore: KeyStore
    private var pgpInterface: PGPInterface?
    private var latestDecryptStatus: Bool = true

    public init(keyStore: KeyStore = AppKeychain.shared) {
        self.keyStore = keyStore
    }

    public func initKeys() throws {
        guard let publicKey: String = keyStore.get(for: PgpKey.PUBLIC.getKeychainKey()),
              let privateKey: String = keyStore.get(for: PgpKey.PRIVATE.getKeychainKey()) else {
            pgpInterface = nil
            throw AppError.keyImport
        }
        do {
            pgpInterface = try GopenPGPInterface(publicArmoredKey: publicKey, privateArmoredKey: privateKey)
        } catch {
            pgpInterface = try ObjectivePGPInterface(publicArmoredKey: publicKey, privateArmoredKey: privateKey)
        }
    }

    public func uninitKeys() {
        pgpInterface = nil
    }

    public func getKeyID() throws -> [String] {
        try checkAndInit()
        return pgpInterface?.keyID ?? []
    }

    public func getShortKeyID() throws -> [String] {
        try checkAndInit()
        return pgpInterface?.shortKeyID.sorted() ?? []
    }

    public func decrypt(encryptedData: Data, keyID: String, requestPGPKeyPassphrase: @escaping (String) -> String) throws -> Data? {
        // Init keys.
        try checkAndInit()
        guard let pgpInterface = pgpInterface else {
            throw AppError.decryption
        }

        var keyID = keyID
        if !pgpInterface.containsPrivateKey(with: keyID) {
            if pgpInterface.keyID.count == 1 {
                keyID = pgpInterface.keyID.first!
            } else {
                throw AppError.pgpPrivateKeyNotFound(keyID: keyID)
            }
        }

        // Remember the previous status and set the current status
        let previousDecryptStatus = latestDecryptStatus
        latestDecryptStatus = false

        // Get the PGP key passphrase.
        var passphrase = ""
        if previousDecryptStatus == false {
            passphrase = requestPGPKeyPassphrase(keyID)
        } else {
            passphrase = keyStore.get(for: AppKeychain.getPGPKeyPassphraseKey(keyID: keyID)) ?? requestPGPKeyPassphrase(keyID)
        }
        // Decrypt.
        guard let result = try pgpInterface.decrypt(encryptedData: encryptedData, keyID: keyID, passphrase: passphrase) else {
            return nil
        }
        // The decryption step has succeed.
        latestDecryptStatus = true
        return result
    }

    public func encrypt(plainData: Data, keyID: String) throws -> Data {
        try checkAndInit()
        guard let pgpInterface = pgpInterface else {
            throw AppError.encryption
        }
        var keyID = keyID
        if !pgpInterface.containsPublicKey(with: keyID) {
            if pgpInterface.keyID.count == 1 {
                keyID = pgpInterface.keyID.first!
            } else {
                throw AppError.pgpPublicKeyNotFound(keyID: keyID)
            }
        }
        return try pgpInterface.encrypt(plainData: plainData, keyID: keyID)
    }

    public var isPrepared: Bool {
        keyStore.contains(key: PgpKey.PUBLIC.getKeychainKey())
            && keyStore.contains(key: PgpKey.PRIVATE.getKeychainKey())
    }

    private func checkAndInit() throws {
        if pgpInterface == nil || !keyStore.contains(key: Globals.pgpKeyPassphrase) {
            try initKeys()
        }
    }
}
