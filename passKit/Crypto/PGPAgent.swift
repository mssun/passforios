//
//  PGPAgent.swift
//  passKit
//
//  Created by Yishi Lin on 2019/7/17.
//  Copyright © 2019 Bob Sun. All rights reserved.
//

public class PGPAgent {

    public static let shared: PGPAgent = PGPAgent()

    private let keyStore: KeyStore
    private var pgpInterface: PgpInterface?
    private var latestDecryptStatus: Bool = true

    public init(keyStore: KeyStore = AppKeychain.shared) {
        self.keyStore = keyStore
    }

    public func initKeys() throws {
        guard let publicKey: String = keyStore.get(for: PgpKey.PUBLIC.getKeychainKey()),
              let privateKey: String = keyStore.get(for: PgpKey.PRIVATE.getKeychainKey()) else {
            pgpInterface = nil
            throw AppError.KeyImport
        }
        do {
            pgpInterface = try GopenPgp(publicArmoredKey: publicKey, privateArmoredKey: privateKey)
        } catch {
            pgpInterface = try ObjectivePgp(publicArmoredKey: publicKey, privateArmoredKey: privateKey)
        }
    }

    public func uninitKeys() {
        pgpInterface = nil
    }

    public func getKeyId() throws -> String? {
        try checkAndInit()
        return pgpInterface?.keyId
    }

    public func getShortKeyId() throws -> String? {
        try checkAndInit()
        return pgpInterface?.shortKeyId
    }

    public func decrypt(encryptedData: Data, keyID: String, requestPGPKeyPassphrase: (String) -> String) throws -> Data? {
        // Remember the previous status and set the current status
        let previousDecryptStatus = self.latestDecryptStatus
        self.latestDecryptStatus = false
        // Init keys.
        try checkAndInit()
        // Get the PGP key passphrase.
        var passphrase = ""
        if previousDecryptStatus == false {
            passphrase = requestPGPKeyPassphrase(keyID)
        } else {
            passphrase = keyStore.get(for: Globals.pgpKeyPassphrase) ?? requestPGPKeyPassphrase(keyID)
        }
        // Decrypt.
        guard let result = try pgpInterface!.decrypt(encryptedData: encryptedData, keyID: keyID, passphrase: passphrase) else {
            return nil
        }
        // The decryption step has succeed.
        self.latestDecryptStatus = true
        return result
    }

    public func encrypt(plainData: Data, keyID: String) throws -> Data {
        try checkAndInit()
        guard let pgpInterface = pgpInterface else {
            throw AppError.Encryption
        }
        return try pgpInterface.encrypt(plainData: plainData, keyID: keyID)
    }

    public var isPrepared: Bool {
        return keyStore.contains(key: PgpKey.PUBLIC.getKeychainKey())
            && keyStore.contains(key: PgpKey.PRIVATE.getKeychainKey())
    }

    private func checkAndInit() throws {
        if pgpInterface == nil || !keyStore.contains(key: Globals.pgpKeyPassphrase) {
            try initKeys()
        }
    }
}
