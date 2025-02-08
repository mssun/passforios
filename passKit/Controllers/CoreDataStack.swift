//
//  CoreDataStack.swift
//  passKit
//
//  Created by Mingshen Sun on 12/28/24.
//  Copyright © 2024 Bob Sun. All rights reserved.
//

import CoreData

public class PersistenceController {
    public static let shared = PersistenceController()
    static let modelName = "pass"

    public func viewContext() -> NSManagedObjectContext {
        container.viewContext
    }

    let container: NSPersistentContainer

    init(isUnitTest: Bool = false) {
        self.container = NSPersistentContainer(name: Self.modelName, managedObjectModel: .sharedModel)
        let description = container.persistentStoreDescriptions.first
        description?.shouldMigrateStoreAutomatically = false
        description?.shouldInferMappingModelAutomatically = false
        if isUnitTest {
            description?.url = URL(fileURLWithPath: "/dev/null")
        }
    }

    public func setup() {
        container.loadPersistentStores { _, error in
            if error != nil {
                self.reinitializePersistentStore()
            }
        }
    }

    func reinitializePersistentStore() {
        deletePersistentStore()
        container.loadPersistentStores { _, finalError in
            if let finalError {
                fatalError("Failed to load persistent stores: \(finalError.localizedDescription)")
            }
        }
        PasswordEntity.initPasswordEntityCoreData(url: Globals.repositoryURL, in: container.viewContext)
        try? container.viewContext.save()
    }

    func deletePersistentStore(inMemoryStore: Bool = false) {
        let coordinator = container.persistentStoreCoordinator

        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
            return
        }
        do {
            if #available(iOS 15.0, *) {
                let storeType: NSPersistentStore.StoreType = inMemoryStore ? .inMemory : .sqlite
                try coordinator.destroyPersistentStore(at: storeURL, type: storeType)
            } else {
                let storeType: String = inMemoryStore ? NSInMemoryStoreType : NSSQLiteStoreType
                try coordinator.destroyPersistentStore(at: storeURL, ofType: storeType)
            }
        } catch {
            fatalError("Failed to destroy persistent store: \(error)")
        }
    }

    public func save() {
        let context = viewContext()

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                fatalError("Failed to save changes: \(error)")
            }
        }
    }
}

extension NSManagedObjectModel {
    static let sharedModel: NSManagedObjectModel = {
        let url = Bundle(identifier: Globals.passKitBundleIdentifier)!.url(forResource: "pass", withExtension: "momd")!
        guard let managedObjectModel = NSManagedObjectModel(contentsOf: url) else {
            fatalError("Failed to create managed object model: \(url)")
        }
        return managedObjectModel
    }()
}
