//
//  DictBasedKeychain.swift
//  passKitTests
//
//  Created by Danny Moesch on 20.07.19.
//  Copyright © 2019 Bob Sun. All rights reserved.
//

import Foundation
import passKit

class DictBasedKeychain: KeyStore {
    private var store: [String: Any] = [:]

    public func add(data: Data?, for key: String) {
        store[key] = data
    }

    public func add(string: String?, for key: String) {
        store[key] = string
    }

    public func contains(key: String) -> Bool {
        store[key] != nil
    }

    public func get(for key: String) -> Data? {
        store[key] as? Data
    }

    public func get(for key: String) -> String? {
        store[key] as? String
    }

    public func removeContent(for key: String) {
        store.removeValue(forKey: key)
    }

    public func removeAllContent() {
        store.removeAll()
    }
}
