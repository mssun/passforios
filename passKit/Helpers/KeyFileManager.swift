//
//  KeyFileManager.swift
//  passKit
//
//  Created by Danny Moesch on 29.06.19.
//  Copyright © 2019 Bob Sun. All rights reserved.
//

public class KeyFileManager {
    public typealias KeyHandler = (Data, String) -> ()

    public static let PublicPgp = KeyFileManager(keyType: PgpKeyType.PUBLIC)
    public static let PrivatePgp = KeyFileManager(keyType: PgpKeyType.PRIVATE)

    private let keyType: PgpKeyType
    private let keyPath: String
    private let keyHandler: KeyHandler

    private convenience init(keyType: PgpKeyType) {
        self.init(keyType: keyType, keyPath: keyType.getFileSharingPath())
    }

    public init(keyType: PgpKeyType, keyPath: String, keyHandler: @escaping KeyHandler = AppKeychain.add) {
        self.keyType = keyType
        self.keyPath = keyPath
        self.keyHandler = keyHandler
    }

    public func importKeyAndDeleteFile() throws {
        guard let keyFileContent = FileManager.default.contents(atPath: keyPath) else {
            throw AppError.ReadingFile(URL(fileURLWithPath: keyPath).lastPathComponent)
        }
        keyHandler(keyFileContent, keyType.getKeychainKey())
        try FileManager.default.removeItem(atPath: keyPath)
    }
    
    public func doesKeyFileExist() -> Bool {
        return FileManager.default.fileExists(atPath: keyPath)
    }
}
