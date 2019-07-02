//
//  AppKeychain.swift
//  passKit
//
//  Created by Danny Moesch on 25.06.19.
//  Copyright © 2019 Bob Sun. All rights reserved.
//

import KeychainAccess

public class AppKeychain {
    
    private static let keychain = Keychain(service: Globals.bundleIdentifier, accessGroup: Globals.groupIdentifier)
        .accessibility(.whenUnlockedThisDeviceOnly)
        .synchronizable(false)

    public static func add(data: Data, for key: String) {
        keychain[data: key] = data
    }

    public static func add(string: String, for key: String) {
        keychain[key] = string
    }

    public static func contains(key: String) -> Bool {
        return (try? keychain.contains(key)) ?? false
    }

    public static func get(for key: String) -> Data? {
        return try? keychain.getData(key)
    }

    public static func get(for key: String) -> String? {
        return try? keychain.getString(key)
    }

    public static func removeContent(for key: String) {
        try? keychain.remove(key)
    }

    public static func removeAllContent() {
        try? keychain.removeAll()
    }
}
