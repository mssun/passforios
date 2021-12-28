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
    private static let keyFileManager = KeyFileManager(keyType: PGPKey.PUBLIC, keyPath: filePath) { _, _ in }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: Self.filePath)
        super.tearDown()
    }

    func testImportKeyFromFileSharing() throws {
        let fileContent = "content".data(using: .ascii)
        var storage: [String: String] = [:]
        let keyFileManager = KeyFileManager(keyType: PGPKey.PRIVATE, keyPath: Self.filePath) { storage[$1] = $0 }

        FileManager.default.createFile(atPath: Self.filePath, contents: fileContent, attributes: nil)
        try keyFileManager.importKeyFromFileSharing()

        XCTAssertFalse(FileManager.default.fileExists(atPath: Self.filePath))
        XCTAssertEqual(storage[PGPKey.PRIVATE.getKeychainKey()], "content")
    }

    func testErrorReadingFile() throws {
        XCTAssertThrowsError(try Self.keyFileManager.importKeyFromFileSharing())
    }

    func testImportKeyFromURL() throws {
        let fileContent = "content".data(using: .ascii)
        let url = URL(fileURLWithPath: Self.filePath)
        var storage: [String: String] = [:]
        let keyFileManager = KeyFileManager(keyType: PGPKey.PRIVATE, keyPath: Self.filePath) { storage[$1] = $0 }

        FileManager.default.createFile(atPath: Self.filePath, contents: fileContent, attributes: nil)
        try keyFileManager.importKey(from: url)

        XCTAssertEqual(storage[PGPKey.PRIVATE.getKeychainKey()], "content")
    }

    func testImportKeyFromString() throws {
        let string = "content"
        var storage: [String: String] = [:]
        let keyFileManager = KeyFileManager(keyType: PGPKey.PRIVATE, keyPath: Self.filePath) { storage[$1] = $0 }

        try keyFileManager.importKey(from: string)

        XCTAssertEqual(storage[PGPKey.PRIVATE.getKeychainKey()], string)
    }

    func testImportKeyFromNonAsciiString() throws {
        XCTAssertThrowsError(try Self.keyFileManager.importKey(from: "≠")) {
            XCTAssertEqual($0 as! AppError, AppError.encoding)
        }
    }

    func testFileExists() {
        FileManager.default.createFile(atPath: Self.filePath, contents: nil, attributes: nil)

        XCTAssertTrue(Self.keyFileManager.doesKeyFileExist())
    }

    func testFileDoesNotExist() {
        XCTAssertFalse(Self.keyFileManager.doesKeyFileExist())
    }
}
