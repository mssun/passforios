//
//  KeyStore.swift
//  passKit
//
//  Created by Danny Moesch on 20.07.19.
//  Copyright © 2019 Bob Sun. All rights reserved.
//

import Foundation

public protocol KeyStore {
    func add(data: Data?, for key: String)
    func add(string: String?, for key: String)
    func contains(key: String) -> Bool
    func get(for key: String) -> Data?
    func get(for key: String) -> String?
    func removeContent(for key: String)
    func removeAllContent()
}
