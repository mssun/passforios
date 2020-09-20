//
//  KeyFileManagerTest.swift
//  passKitTests
//
//  Created by Danny Moesch on 01.07.19.
//  Copyright © 2019 Bob Sun. All rights reserved.
//

import XCTest

@testable import passKit

class KeyFileManagerTest: XCTestCase {
    private static let filePath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test.txt").path
    private static let keyFileManager = KeyFileManager(keyType: PgpKey.PUBLIC, keyPath: filePath) { _, _ in }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: KeyFileManagerTest.filePath)
        super.tearDown()
    }

    func testImportKeyFromFileSharing() throws {
        let fileContent = "content".data(using: .ascii)
        var storage: [String: String] = [:]
        let keyFileManager = KeyFileManager(keyType: PgpKey.PRIVATE, keyPath: KeyFileManagerTest.filePath) { storage[$1] = $0 }

        FileManager.default.createFile(atPath: KeyFileManagerTest.filePath, contents: fileContent, attributes: nil)
        try keyFileManager.importKeyFromFileSharing()

        XCTAssertFalse(FileManager.default.fileExists(atPath: KeyFileManagerTest.filePath))
        XCTAssertEqual(storage[PgpKey.PRIVATE.getKeychainKey()], "content")
    }

    func testErrorReadingFile() throws {
        XCTAssertThrowsError(try KeyFileManagerTest.keyFileManager.importKeyFromFileSharing())
    }

    func testImportKeyFromUrl() throws {
        let fileContent = "content".data(using: .ascii)
        let url = URL(fileURLWithPath: KeyFileManagerTest.filePath)
        var storage: [String: String] = [:]
        let keyFileManager = KeyFileManager(keyType: PgpKey.PRIVATE, keyPath: KeyFileManagerTest.filePath) { storage[$1] = $0 }

        FileManager.default.createFile(atPath: KeyFileManagerTest.filePath, contents: fileContent, attributes: nil)
        try keyFileManager.importKey(from: url)

        XCTAssertEqual(storage[PgpKey.PRIVATE.getKeychainKey()], "content")
    }

    func testImportKeyFromString() throws {
        let string = "content"
        var storage: [String: String] = [:]
        let keyFileManager = KeyFileManager(keyType: PgpKey.PRIVATE, keyPath: KeyFileManagerTest.filePath) { storage[$1] = $0 }

        try keyFileManager.importKey(from: string)

        XCTAssertEqual(storage[PgpKey.PRIVATE.getKeychainKey()], string)
    }

    func testImportKeyFromNonAsciiString() throws {
        XCTAssertThrowsError(try KeyFileManagerTest.keyFileManager.importKey(from: "≠")) {
            XCTAssertEqual($0 as! AppError, AppError.encoding)
        }
    }

    func testFileExists() {
        FileManager.default.createFile(atPath: KeyFileManagerTest.filePath, contents: nil, attributes: nil)

        XCTAssertTrue(KeyFileManagerTest.keyFileManager.doesKeyFileExist())
    }

    func testFileDoesNotExist() {
        XCTAssertFalse(KeyFileManagerTest.keyFileManager.doesKeyFileExist())
    }
}
