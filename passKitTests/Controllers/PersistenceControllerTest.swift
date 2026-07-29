//
//  PersistenceControllerTest.swift
//  passKitTests
//
//  Created by Lysann Tranvouez on 9/3/26.
//  Copyright © 2026 Bob Sun. All rights reserved.
//

import CoreData
import XCTest

@testable import passKit

final class PersistenceControllerTest: XCTestCase {
    func testModelLoads() {
        let controller = PersistenceController.forUnitTests()
        let context = controller.viewContext()

        let entityNames = context.persistentStoreCoordinator!.managedObjectModel.entities.map(\.name)
        XCTAssertEqual(entityNames, ["PasswordEntity"])
    }

    func testInsertAndFetch() {
        let controller = PersistenceController.forUnitTests()
        let context = controller.viewContext()
        XCTAssertEqual(PasswordEntity.fetchAll(in: context).count, 0)

        PasswordEntity.insert(name: "test", path: "test.gpg", isDir: false, into: context)
        try? context.save()

        XCTAssertEqual(PasswordEntity.fetchAll(in: context).count, 1)
    }

    func testReinitializePersistentStoreClearsData() {
        let controller = PersistenceController.forUnitTests()
        let context = controller.viewContext()

        PasswordEntity.insert(name: "test1", path: "test1.gpg", isDir: false, into: context)
        PasswordEntity.insert(name: "test2", path: "test2.gpg", isDir: false, into: context)
        try? context.save()
        XCTAssertEqual(PasswordEntity.fetchAll(in: context).count, 2)

        controller.reinitializePersistentStore()

        // After reinitialize, old data should be gone
        // (reinitializePersistentStore rescans PersistenceController's repositoryURL, which
        // forUnitTests() points at a fresh, isolated temp directory, so the result should be
        // an empty store regardless of what's on the real device)
        let remaining = PasswordEntity.fetchAll(in: context)
        XCTAssertEqual(remaining.count, 0)
    }

    func testMultipleControllersAreIndependent() {
        let controller1 = PersistenceController.forUnitTests()
        let controller2 = PersistenceController.forUnitTests()

        let context1 = controller1.viewContext()
        let context2 = controller2.viewContext()

        PasswordEntity.insert(name: "only-in-1", path: "only-in-1.gpg", isDir: false, into: context1)
        try? context1.save()

        XCTAssertEqual(PasswordEntity.fetchAll(in: context1).count, 1)
        XCTAssertEqual(PasswordEntity.fetchAll(in: context2).count, 0)
    }

    func testSaveAndLoadFromFile() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let storeURL = tempDir.appendingPathComponent("test.sqlite")

        // Write
        let controller1 = PersistenceController(storeURL: storeURL)
        let context1 = controller1.viewContext()
        PasswordEntity.insert(name: "saved", path: "saved.gpg", isDir: false, into: context1)
        PasswordEntity.insert(name: "dir", path: "dir", isDir: true, into: context1)
        controller1.save()

        // Load in a fresh controller from the same file
        let controller2 = PersistenceController(storeURL: storeURL)
        let context2 = controller2.viewContext()
        let allEntities = PasswordEntity.fetchAll(in: context2)

        XCTAssertEqual(allEntities.count, 2)
        XCTAssertNotNil(allEntities.first { $0.name == "saved" && !$0.isDir })
        XCTAssertNotNil(allEntities.first { $0.name == "dir" && $0.isDir })
    }
}
