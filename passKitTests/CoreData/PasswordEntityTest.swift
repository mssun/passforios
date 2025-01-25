//
//  PasswordEntityTest.swift
//  pass
//
//  Created by Mingshen Sun on 1/4/25.
//  Copyright © 2025 Bob Sun. All rights reserved.
//

import CoreData
import XCTest

@testable import passKit

final class PasswordEntityTest: CoreDataTestCase {
    func testFetchAll() throws {
        let context = controller.viewContext()
        let expectedCount = 5
        (0 ..< expectedCount).forEach { index in
            let name = String(format: "Generated %05d", index)
            let path = String(format: "/%05d", index)
            PasswordEntity.insert(name: name, path: path, isDir: false, into: context)
        }
        let count = PasswordEntity.fetchAllPassword(in: context).count
        XCTAssertEqual(expectedCount, count)
        PasswordEntity.deleteAll(in: context)
    }

    func testTotalNumber() throws {
        let context = controller.viewContext()
        PasswordEntity.insert(name: "1", path: "path1", isDir: false, into: context)
        PasswordEntity.insert(name: "2", path: "path2", isDir: false, into: context)
        PasswordEntity.insert(name: "3", path: "path3", isDir: true, into: context)
        XCTAssertEqual(2, PasswordEntity.totalNumber(in: context))
        PasswordEntity.deleteAll(in: context)
    }

    func testFetchUnsynced() throws {
        let context = controller.viewContext()
        let syncedPasswordEntity = PasswordEntity.insert(name: "1", path: "path", isDir: false, into: context)
        syncedPasswordEntity.isSynced = true

        let expectedCount = 5
        (0 ..< expectedCount).forEach { index in
            let name = String(format: "Generated %05d", index)
            let path = String(format: "/%05d", index)
            PasswordEntity.insert(name: name, path: path, isDir: false, into: context)
        }
        let count = PasswordEntity.fetchUnsynced(in: context).count
        XCTAssertEqual(expectedCount, count)
        PasswordEntity.deleteAll(in: context)
    }

    func testFetchByPath() throws {
        let context = controller.viewContext()
        PasswordEntity.insert(name: "1", path: "path1", isDir: false, into: context)
        PasswordEntity.insert(name: "2", path: "path2", isDir: true, into: context)
        let passwordEntity = PasswordEntity.fetch(by: "path1", in: context)!
        XCTAssertEqual(passwordEntity.path, "path1")
        XCTAssertEqual(passwordEntity.name, "1")
    }

    func testFetchByParent() throws {
        let context = controller.viewContext()
        let parent = PasswordEntity.insert(name: "parent", path: "path1", isDir: true, into: context)
        let child1 = PasswordEntity.insert(name: "child1", path: "path2", isDir: false, into: context)
        let child2 = PasswordEntity.insert(name: "child2", path: "path3", isDir: true, into: context)
        let child3 = PasswordEntity.insert(name: "child3", path: "path4", isDir: false, into: context)
        parent.children = [child1, child2]
        child2.children = [child3]
        let childern = PasswordEntity.fetch(by: parent, in: context)
        XCTAssertEqual(childern.count, 2)
    }

    func testDeleteRecursively() throws {
        let context = controller.viewContext()

        let parent = PasswordEntity.insert(name: "parent", path: "path1", isDir: true, into: context)
        let child1 = PasswordEntity.insert(name: "child1", path: "path2", isDir: true, into: context)
        let child2 = PasswordEntity.insert(name: "child2", path: "path3", isDir: false, into: context)
        let child3 = PasswordEntity.insert(name: "child3", path: "path4", isDir: false, into: context)
        parent.children = [child1, child2]
        child1.children = [child3]
        PasswordEntity.deleteRecursively(entity: child2, in: context)
        PasswordEntity.deleteRecursively(entity: child3, in: context)

        XCTAssertEqual(PasswordEntity.fetchAll(in: context).count, 0)
    }
}
