//
//  PasswordEntity.swift
//  passKit
//
//  Created by Mingshen Sun on 11/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import CoreData
import Foundation
import ObjectiveGit
import SwiftyUserDefaults

public final class PasswordEntity: NSManagedObject, Identifiable {
    /// Name of the password, i.e., filename without extension.
    @NSManaged public var name: String

    /// A Boolean value indicating whether the entity is a directory.
    @NSManaged public var isDir: Bool

    /// A Boolean value indicating whether the entity is synced with remote repository.
    @NSManaged public var isSynced: Bool

    /// The relative file path of the password or directory.
    @NSManaged public var path: String

    /// The thumbnail image of the password if there is a url entry in the password.
    @NSManaged public var image: Data?

    /// The parent password entity.
    @NSManaged public var parent: PasswordEntity?

    /// A set of child password entities.
    @NSManaged public var children: Set<PasswordEntity>

    @nonobjc
    public static func fetchRequest() -> NSFetchRequest<PasswordEntity> {
        NSFetchRequest<PasswordEntity>(entityName: "PasswordEntity")
    }

    /// A String value with password directory and name, i.e., path without extension.
    public var nameWithDir: String {
        (path as NSString).deletingPathExtension
    }

    public var dirText: String {
        getDirArray().joined(separator: " > ")
    }

    public func fileURL(in directoryURL: URL) -> URL {
        directoryURL.appendingPathComponent(path)
    }

    public func getDirArray() -> [String] {
        var parentEntity = parent
        var passwordCategoryArray: [String] = []
        while let current = parentEntity {
            passwordCategoryArray.append(current.name)
            parentEntity = current.parent
        }
        passwordCategoryArray.reverse()
        return passwordCategoryArray
    }

    public static func fetchAll(in context: NSManagedObjectContext) -> [PasswordEntity] {
        let request = Self.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        return (try? context.fetch(request) as? [Self]) ?? []
    }

    public static func fetchAllPassword(in context: NSManagedObjectContext) -> [PasswordEntity] {
        let request = Self.fetchRequest()
        request.predicate = NSPredicate(format: "isDir = false")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        return (try? context.fetch(request) as? [Self]) ?? []
    }

    public static func totalNumber(in context: NSManagedObjectContext) -> Int {
        let request = Self.fetchRequest()
        request.predicate = NSPredicate(format: "isDir = false")
        return (try? context.count(for: request)) ?? 0
    }

    public static func fetchUnsynced(in context: NSManagedObjectContext) -> [PasswordEntity] {
        let request = Self.fetchRequest()
        request.predicate = NSPredicate(format: "isSynced = false")
        return (try? context.fetch(request) as? [Self]) ?? []
    }

    public static func fetch(by path: String, in context: NSManagedObjectContext) -> PasswordEntity? {
        let request = Self.fetchRequest()
        request.predicate = NSPredicate(format: "path = %@", path)
        return try? context.fetch(request).first as? Self
    }

    public static func fetch(by path: String, isDir: Bool, in context: NSManagedObjectContext) -> PasswordEntity? {
        let request = Self.fetchRequest()

        request.predicate = NSPredicate(format: "path = %@ and isDir = %@", path, isDir as NSNumber)
        return try? context.fetch(request).first as? Self
    }

    public static func fetch(by parent: PasswordEntity?, in context: NSManagedObjectContext) -> [PasswordEntity] {
        let request = Self.fetchRequest()
        request.predicate = NSPredicate(format: "parent = %@", parent ?? 0)
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        return (try? context.fetch(request) as? [Self]) ?? []
    }

    public static func updateAllToSynced(in context: NSManagedObjectContext) -> Int {
        let request = NSBatchUpdateRequest(entity: Self.entity())
        request.resultType = .updatedObjectsCountResultType
        request.predicate = NSPredicate(format: "isSynced = false")
        request.propertiesToUpdate = ["isSynced": true]
        let result = try? context.execute(request) as? NSBatchUpdateResult
        return result?.result as? Int ?? 0
    }

    public static func deleteRecursively(entity: PasswordEntity, in context: NSManagedObjectContext) {
        var currentEntity: PasswordEntity? = entity

        while let node = currentEntity, node.children.isEmpty {
            let parent = node.parent
            context.delete(node)
            try? context.save()
            currentEntity = parent
        }
    }

    public static func deleteAll(in context: NSManagedObjectContext) {
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: Self.fetchRequest())
        _ = try? context.execute(deleteRequest)
    }

    public static func exists(password: Password, in context: NSManagedObjectContext) -> Bool {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "name = %@ and path = %@ and isDir = false", password.name, password.path)
        if let count = try? context.count(for: request) {
            return count > 0
        }
        return false
    }

    @discardableResult
    public static func insert(name: String, path: String, isDir: Bool, into context: NSManagedObjectContext) -> PasswordEntity {
        let entity = PasswordEntity(context: context)
        entity.name = name
        entity.path = path
        entity.isDir = isDir
        entity.isSynced = false
        return entity
    }

    public static func initPasswordEntityCoreData(url: URL, in context: NSManagedObjectContext) {
        let localFileManager = FileManager.default
        let url = url.resolvingSymlinksInPath()

        let root = {
            let entity = PasswordEntity(context: context)
            entity.name = "root"
            entity.isDir = true
            entity.path = ""
            return entity
        }()
        var queue = [root]
        while !queue.isEmpty {
            let current = queue.removeFirst()
            let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey])
            let options = FileManager.DirectoryEnumerationOptions([.skipsHiddenFiles, .skipsSubdirectoryDescendants])
            let currentURL = url.appendingPathComponent(current.path)
            guard let directoryEnumerator = localFileManager.enumerator(at: currentURL, includingPropertiesForKeys: Array(resourceKeys), options: options) else {
                continue
            }
            for case let fileURL as URL in directoryEnumerator {
                let fileURL = fileURL.resolvingSymlinksInPath()
                guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                      let isDirectory = resourceValues.isDirectory,
                      let name = resourceValues.name
                else {
                    continue
                }
                let passwordEntity = PasswordEntity(context: context)
                passwordEntity.isDir = isDirectory
                if isDirectory {
                    passwordEntity.name = name
                    queue.append(passwordEntity)
                } else {
                    if (name as NSString).pathExtension == "gpg" {
                        passwordEntity.name = (name as NSString).deletingPathExtension
                    } else {
                        passwordEntity.name = name
                    }
                }
                passwordEntity.parent = current
                passwordEntity.path = String(fileURL.path.dropFirst(url.path.count + 1))
            }
        }
        context.delete(root)
    }
}

public extension PasswordEntity {
    @objc(addChildrenObject:)
    @NSManaged
    func addToChildren(_ value: PasswordEntity)

    @objc(removeChildrenObject:)
    @NSManaged
    func removeFromChildren(_ value: PasswordEntity)

    @objc(addChildren:)
    @NSManaged
    func addToChildren(_ values: NSSet)

    @objc(removeChildren:)
    @NSManaged
    func removeFromChildren(_ values: NSSet)
}
