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

    // MARK: - initPasswordEntityCoreData tests

    func testInitPasswordEntityCoreDataBuildsTree() throws {
        let rootDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: rootDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: rootDir) }

        // Create directory structure:
        //   email/
        //     work.gpg
        //     personal.gpg
        //   social/
        //     mastodon.gpg
        //   toplevel.gpg
        //   notes.txt          (non-.gpg file)
        let emailDir = rootDir.appendingPathComponent("email")
        let socialDir = rootDir.appendingPathComponent("social")
        try FileManager.default.createDirectory(at: emailDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: socialDir, withIntermediateDirectories: true)
        try Data("test1".utf8).write(to: emailDir.appendingPathComponent("work.gpg"))
        try Data("test2".utf8).write(to: emailDir.appendingPathComponent("personal.gpg"))
        try Data("test3".utf8).write(to: socialDir.appendingPathComponent("mastodon.gpg"))
        try Data("test4".utf8).write(to: rootDir.appendingPathComponent("toplevel.gpg"))
        try Data("test5".utf8).write(to: rootDir.appendingPathComponent("notes.txt"))

        let context = controller.viewContext()
        PasswordEntity.initPasswordEntityCoreData(url: rootDir, in: context)

        // Verify total counts
        let allEntities = PasswordEntity.fetchAll(in: context)
        let files = allEntities.filter { !$0.isDir }
        let dirs = allEntities.filter(\.isDir)
        XCTAssertEqual(files.count, 5) // 4 .gpg + 1 .txt
        XCTAssertEqual(dirs.count, 2) // email, social

        // Verify .gpg extension is stripped
        let workEntity = allEntities.first { $0.path == "email/work.gpg" }
        XCTAssertNotNil(workEntity)
        XCTAssertEqual(workEntity!.name, "work")

        // Verify non-.gpg file keeps its extension
        let notesEntity = allEntities.first { $0.path == "notes.txt" }
        XCTAssertNotNil(notesEntity)
        XCTAssertEqual(notesEntity!.name, "notes.txt")

        // Verify parent-child relationships
        let emailEntity = allEntities.first { $0.path == "email" && $0.isDir }
        XCTAssertNotNil(emailEntity)
        XCTAssertEqual(emailEntity!.children.count, 2)

        // Verify top-level files have no parent (root was deleted)
        let toplevelEntity = allEntities.first { $0.path == "toplevel.gpg" }
        XCTAssertNotNil(toplevelEntity)
        XCTAssertEqual(toplevelEntity!.name, "toplevel")
        XCTAssertNil(toplevelEntity!.parent)
    }

    func testInitPasswordEntityCoreDataSkipsHiddenFiles() throws {
        let rootDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: rootDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: rootDir) }

        try Data("test".utf8).write(to: rootDir.appendingPathComponent("visible.gpg"))
        try Data("test".utf8).write(to: rootDir.appendingPathComponent(".hidden.gpg"))
        try Data("test".utf8).write(to: rootDir.appendingPathComponent(".gpg-id"))
        try FileManager.default.createDirectory(at: rootDir.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try Data("test".utf8).write(to: rootDir.appendingPathComponent(".git/config"))

        let context = controller.viewContext()
        PasswordEntity.initPasswordEntityCoreData(url: rootDir, in: context)

        let allEntities = PasswordEntity.fetchAll(in: context)
        XCTAssertEqual(allEntities.count, 1)
        XCTAssertEqual(allEntities.first!.name, "visible")
    }

    func testInitPasswordEntityCoreDataHandlesEmptyDirectory() throws {
        let rootDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: rootDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: rootDir) }

        try FileManager.default.createDirectory(at: rootDir.appendingPathComponent("emptydir"), withIntermediateDirectories: true)

        let context = controller.viewContext()
        PasswordEntity.initPasswordEntityCoreData(url: rootDir, in: context)

        let allEntities = PasswordEntity.fetchAll(in: context)
        let dirs = allEntities.filter(\.isDir)
        let files = allEntities.filter { !$0.isDir }
        XCTAssertEqual(dirs.count, 1)
        XCTAssertEqual(dirs.first!.name, "emptydir")
        XCTAssertEqual(dirs.first!.children.count, 0)
        XCTAssertEqual(files.count, 0)
    }
}
