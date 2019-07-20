//
//  AppKeychain.swift
//  passKit
//
//  Created by Danny Moesch on 25.06.19.
//  Copyright © 2019 Bob Sun. All rights reserved.
//

import KeychainAccess

public class AppKeychain: KeyStore {

    public static let shared = AppKeychain()
    
    private let keychain = Keychain(service: Globals.bundleIdentifier, accessGroup: Globals.groupIdentifier)
        .accessibility(.whenUnlockedThisDeviceOnly)
        .synchronizable(false)

    public func add(data: Data?, for key: String) {
        keychain[data: key] = data
    }

    public func add(string: String?, for key: String) {
        keychain[key] = string
    }

    public func contains(key: String) -> Bool {
        return (try? keychain.contains(key)) ?? false
    }

    public func get(for key: String) -> Data? {
        return try? keychain.getData(key)
    }

    public func get(for key: String) -> String? {
        return try? keychain.getString(key)
    }

    public func removeContent(for key: String) {
        try? keychain.remove(key)
    }

    public func removeAllContent() {
        try? keychain.removeAll()
    }
}
