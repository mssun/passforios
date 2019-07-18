//
//  PGPAgent.swift
//  passKit
//
//  Created by Yishi Lin on 2019/7/17.
//  Copyright © 2019 Bob Sun. All rights reserved.
//

import Foundation
import ObjectivePGP
import KeychainAccess
import Crypto

public class PGPAgent {

    private let keyStore: KeyStore

    public init(keyStore: KeyStore = AppKeychain.shared) {
        self.keyStore = keyStore
    }
    
    public var pgpKeyID: String?
    // PGP passphrase
    public var passphrase: String? {
        set {
            keyStore.add(string: newValue, for: "pgpKeyPassphrase")
        }
        get {
            return keyStore.get(for: "pgpKeyPassphrase")
        }
    }
    
    // Gopenpgpwrapper
    private var publicKey: CryptoKeyRing? {
        didSet {
            var err: NSError? = nil
            let fp = publicKey?.getFingerprint(&err)
            if err == nil && fp != nil {
                pgpKeyID = String(fp!.suffix(8)).uppercased()
            } else {
                pgpKeyID = ""
            }
        }
    }
    private var privateKey: CryptoKeyRing?
    // ObjectivePGP
    private let keyring = ObjectivePGP.defaultKeyring
    private var publicKeyV2: Key? {
        didSet {
            pgpKeyID = publicKeyV2?.keyID.shortIdentifier
        }
    }
    private var privateKeyV2: Key?
    
    public var isImported: Bool {
        get {
            return (publicKey != nil || publicKeyV2 != nil) && (privateKey != nil || privateKeyV2 != nil)
        }
    }
    public var isFileSharingReady: Bool {
        get {
            return KeyFileManager.PublicPgp.doesKeyFileExist() && KeyFileManager.PrivatePgp.doesKeyFileExist()
        }
    }
    
    public func initPGPKeys() throws {
        try initPGPKey(.PUBLIC)
        try initPGPKey(.PRIVATE)
    }
    
    public func initPGPKey(_ keyType: PgpKey) throws {
        // Clean up the previously set public/private key.
        switch keyType {
        case .PUBLIC:
            self.publicKey = nil
            self.publicKeyV2 = nil
        case .PRIVATE:
            self.privateKey = nil
            self.privateKeyV2 = nil
        }
        
        // Read the key data from keychain.
        guard let pgpKeyData: Data = keyStore.get(for: keyType.getKeychainKey()) else {
            throw AppError.KeyImport
        }
        
        // Remove the key data from keychain temporary, in case the following step crashes repeatedly.
        keyStore.removeContent(for: keyType.getKeychainKey())
        
        // Try GopenPGP first.
        let pgp = CryptoGetGopenPGP()
        
        // Treat keys as binary first
        if let key = try? pgp?.buildKeyRing(pgpKeyData) {
            switch keyType {
            case .PUBLIC:
                self.publicKey = key
            case .PRIVATE:
                self.privateKey = key
            }
            keyStore.add(data: pgpKeyData, for: keyType.getKeychainKey())
            return
        }
        
        // Treat key as ASCII armored keys if binary fails
        if let key = try? pgp?.buildKeyRingArmored(String(data: pgpKeyData, encoding: .ascii)) {
            switch keyType {
            case .PUBLIC:
                self.publicKey = key
            case .PRIVATE:
                self.privateKey = key
            }
            keyStore.add(data: pgpKeyData, for: keyType.getKeychainKey())
            return
        }
        
        // Try ObjectivePGP as a backup plan.
        // [ObjectivePGP.readKeys MAY CRASH!!!]
        if let keys = try? ObjectivePGP.readKeys(from: pgpKeyData),
            let key = keys.first {
            keyring.import(keys: keys)
            switch keyType {
            case .PUBLIC:
                self.publicKeyV2 = key
            case .PRIVATE:
                self.privateKeyV2 = key
            }
            keyStore.add(data: pgpKeyData, for: keyType.getKeychainKey())
            return
        }
        
        throw AppError.KeyImport
    }
    
    public func initPGPKey(from url: URL, keyType: PgpKey) throws {
        let pgpKeyData = try Data(contentsOf: url)
        keyStore.add(data: pgpKeyData, for: keyType.getKeychainKey())
        try initPGPKey(keyType)
    }
    
    public func initPGPKey(with armorKey: String, keyType: PgpKey) throws {
        let pgpKeyData = armorKey.data(using: .ascii)!
        keyStore.add(data: pgpKeyData, for: keyType.getKeychainKey())
        try initPGPKey(keyType)
    }
    
    public func initPGPKeyFromFileSharing() throws {
        try KeyFileManager.PublicPgp.importKeyAndDeleteFile(keyHandler: keyStore.add)
        try KeyFileManager.PrivatePgp.importKeyAndDeleteFile(keyHandler: keyStore.add)
        try initPGPKeys()
    }
    
    public func decrypt(encryptedData: Data, requestPGPKeyPassphrase: () -> String) throws -> Data? {
        guard privateKey != nil || privateKeyV2 != nil else {
            throw AppError.PgpPublicKeyNotExist
        }
        let passphrase = self.passphrase ?? requestPGPKeyPassphrase()
        // Try Gopenpgp.
        if privateKey != nil {
            try privateKey?.unlock(withPassphrase: passphrase)
            
            var err : NSError? = nil
            var message = CryptoNewPGPMessageFromArmored(String(data: encryptedData, encoding: .ascii), &err)
            if err != nil {
                message = CryptoNewPGPMessage(encryptedData)
            }
            
            if let decryptedData = try? privateKey?.decrypt(message, verifyKey: nil, verifyTime: 0) {
                return decryptedData.data
            }
        }
        // Try ObjectivePGP.
        if privateKeyV2 != nil {
            if let decryptedData = try? ObjectivePGP.decrypt(encryptedData, andVerifySignature: false, using: keyring.keys, passphraseForKey: {(_) in passphrase}) {
                return decryptedData
            }
        }
        throw AppError.Decryption
    }
    
    public func encrypt(plainData: Data) throws -> Data {
        guard publicKey != nil || publicKeyV2 != nil else {
            throw AppError.PgpPublicKeyNotExist
        }
        // Try Gopenpgp.
        if publicKey != nil {
            if let encryptedData = try? publicKey?.encrypt(CryptoNewPlainMessageFromString(String(data: plainData, encoding: .utf8)), privateKey: nil) {
                if SharedDefaults[.encryptInArmored] {
                    var err : NSError? = nil
                    let armor = encryptedData.getArmored(&err)
                    if err == nil {
                        return armor.data(using: .ascii)!
                    }
                } else {
                    return encryptedData.getBinary()!
                }
            }
        }
        
        // Try ObjectivePGP.
        if publicKeyV2 != nil {
            if let encryptedData = try? ObjectivePGP.encrypt(plainData, addSignature: false, using: keyring.keys, passphraseForKey: nil) {
                if SharedDefaults[.encryptInArmored] {
                    return Armor.armored(encryptedData, as: .message).data(using: .utf8)!
                } else {
                    return encryptedData
                }
            }
        }
        throw AppError.Encryption
    }
    
    public func removePGPKeys() {
        keyStore.removeContent(for: PgpKey.PUBLIC.getKeychainKey())
        keyStore.removeContent(for: PgpKey.PRIVATE.getKeychainKey())
        passphrase = nil
        publicKey = nil
        privateKey = nil
        publicKeyV2 = nil
        privateKeyV2 = nil
        keyring.deleteAll()
    }
}
