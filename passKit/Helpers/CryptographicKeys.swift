//
//  CryptographicKeys.swift
//  passKit
//
//  Created by Danny Moesch on 29.06.19.
//  Copyright © 2019 Bob Sun. All rights reserved.
//

public protocol CryptographicKey {
    func getKeychainKey() -> String
    func getFileSharingPath() -> String
}

public enum PgpKey: CryptographicKey {
    case PUBLIC
    case PRIVATE

    public func getKeychainKey() -> String {
        switch self {
        case .PUBLIC:
            return "pgpPublicKey"
        case .PRIVATE:
            return "pgpPrivateKey"
        }
    }

    public func getFileSharingPath() -> String {
        switch self {
        case .PUBLIC:
            return Globals.iTunesFileSharingPGPPublic
        case .PRIVATE:
            return Globals.iTunesFileSharingPGPPrivate
        }
    }
}

