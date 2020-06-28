//
//  PGPKeyImporter.swift
//  pass
//
//  Created by Danny Moesch on 07.02.20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import passKit

protocol PGPKeyImporter: KeyImporter {
    func doAfterImport()

    func saveImportedKeys()
}

extension PGPKeyImporter {
    static var isCurrentKeySource: Bool {
        Defaults.pgpKeySource == Self.keySource
    }

    func doAfterImport() {}
}
