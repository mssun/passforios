//
//  KeyImporter.swift
//  pass
//
//  Created by Danny Moesch on 15.02.20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import passKit

protocol KeyImporter {

    static var keySource: KeySource { get }

    static var label: String { get }

    static var isCurrentKeySource: Bool { get }

    static var menuLabel: String { get }

    func isReadyToUse() -> Bool

    func importKeys() throws
}

extension KeyImporter {

    static var isCurrentKeySource: Bool {
        return Defaults.gitSSHKeySource == Self.keySource
    }

    static var menuLabel: String {
        if isCurrentKeySource {
            return "✓ \(Self.label)"
        }
        return Self.label
    }
}
