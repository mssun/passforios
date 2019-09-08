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

    public init(keyStore: KeyStore = AppKeychain.shared) {
        self.keyStore = keyStore
    }

    public func initKeys() throws {
        guard let publicKey: String = keyStore.get(for: PgpKey.PUBLIC.getKeychainKey()),
              let privateKey: String = keyStore.get(for: PgpKey.PRIVATE.getKeychainKey()) else {
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

    public var keyId: String? {
        return pgpInterface?.keyId
    }

    public func decrypt(encryptedData: Data, requestPGPKeyPassphrase: () -> String) throws -> Data? {
        try checkAndInit()
        let passphrase = keyStore.get(for: Globals.pgpKeyPassphrase) ?? requestPGPKeyPassphrase()
        return try pgpInterface!.decrypt(encryptedData: encryptedData, passphrase: passphrase)
    }

    public func encrypt(plainData: Data) throws -> Data {
        try checkAndInit()
        guard let pgpInterface = pgpInterface else {
            throw AppError.Encryption
        }
        return try pgpInterface.encrypt(plainData: plainData)
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
