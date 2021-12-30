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

    func add(string: String?, for key: String) {
        store[key] = string
    }

    func contains(key: String) -> Bool {
        store[key] != nil
    }

    func get(for key: String) -> String? {
        store[key] as? String
    }

    func removeContent(for key: String) {
        store.removeValue(forKey: key)
    }

    func removeAllContent() {
        store.removeAll()
    }
}
