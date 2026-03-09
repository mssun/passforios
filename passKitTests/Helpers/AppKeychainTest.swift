//
//  AppKeychainTest.swift
//  passKitTests
//
//  Created by Lysann Tranvouez on 9/3/26.
//  Copyright © 2026 Bob Sun. All rights reserved.
//

import XCTest

@testable import passKit

final class AppKeychainTest: XCTestCase {
    private let keychain = AppKeychain.shared
    private let testPrefix = "test.AppKeychainTest."

    override func tearDown() {
        super.tearDown()
        keychain.removeAllContent(withPrefix: testPrefix)
    }

    private func key(_ name: String) -> String {
        "\(testPrefix)\(name)"
    }

    // MARK: - Basic round-trip

    func testAddAndGet() {
        keychain.add(string: "hello", for: key("addGet"))

        XCTAssertEqual(keychain.get(for: key("addGet")), "hello")
    }

    func testGetMissingKeyReturnsNil() {
        XCTAssertNil(keychain.get(for: key("nonexistent")))
    }

    func testOverwriteValue() {
        keychain.add(string: "first", for: key("overwrite"))
        keychain.add(string: "second", for: key("overwrite"))

        XCTAssertEqual(keychain.get(for: key("overwrite")), "second")
    }

    func testAddNilRemovesValue() {
        keychain.add(string: "value", for: key("addNil"))
        keychain.add(string: nil, for: key("addNil"))

        XCTAssertNil(keychain.get(for: key("addNil")))
        XCTAssertFalse(keychain.contains(key: key("addNil")))
    }

    // MARK: - contains

    func testContainsReturnsTrueForExistingKey() {
        keychain.add(string: "value", for: key("exists"))

        XCTAssertTrue(keychain.contains(key: key("exists")))
    }

    func testContainsReturnsFalseForMissingKey() {
        XCTAssertFalse(keychain.contains(key: key("missing")))
    }

    // MARK: - removeContent

    func testRemoveContent() {
        keychain.add(string: "value", for: key("remove"))
        keychain.removeContent(for: key("remove"))

        XCTAssertNil(keychain.get(for: key("remove")))
        XCTAssertFalse(keychain.contains(key: key("remove")))
    }

    func testRemoveContentForMissingKeyDoesNotThrow() {
        keychain.removeContent(for: key("neverExisted"))
        // No assertion needed — just verifying it doesn't crash
    }

    // MARK: - removeAllContent(withPrefix:)

    func testRemoveAllContentWithPrefix() {
        keychain.add(string: "1", for: key("prefixA.one"))
        keychain.add(string: "2", for: key("prefixA.two"))
        keychain.add(string: "3", for: key("prefixB.one"))

        keychain.removeAllContent(withPrefix: key("prefixA"))

        XCTAssertNil(keychain.get(for: key("prefixA.one")))
        XCTAssertNil(keychain.get(for: key("prefixA.two")))
        XCTAssertEqual(keychain.get(for: key("prefixB.one")), "3")
    }

    func testRemoveAllContentWithPrefixNoMatches() {
        keychain.add(string: "value", for: key("survivor"))

        keychain.removeAllContent(withPrefix: key("noMatch"))

        XCTAssertEqual(keychain.get(for: key("survivor")), "value")
    }
}
