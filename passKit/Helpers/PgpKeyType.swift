//
//  PgpKeyType.swift
//  passKit
//
//  Created by Danny Moesch on 29.06.19.
//  Copyright © 2019 Bob Sun. All rights reserved.
//

public enum PgpKeyType {
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

    func getFileSharingPath() -> String {
        switch self {
        case .PUBLIC:
            return Globals.iTunesFileSharingPGPPublic
        case .PRIVATE:
            return Globals.iTunesFileSharingPGPPrivate
        }
    }
}
