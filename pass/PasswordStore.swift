//
//  PasswordStore.swift
//  pass
//
//  Created by Mingshen Sun on 19/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import SwiftGit2
import Result
import CoreData
import UIKit

class PasswordStore {
    static let shared = PasswordStore()
    
    let storeURL = URL(fileURLWithPath: "\(NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])/password-store")
    var storeRepo: Repository?
    
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext

    
    private init() {
        let result = Repository.at(storeURL)
        if case .success(let r) = result {
            storeRepo = r
        }
    }
    
    func cloneRemoteRepo(remoteRepoURL: URL) -> Bool{
        print("start cloning remote repo")
        let fm = FileManager.default
        if (storeRepo != nil) {
            print("remove item")
            do {
                try fm.removeItem(at: storeURL)
            } catch let error as NSError {
                print(error.debugDescription)
            }
        }
        let cloneResult = Repository.clone(from: remoteRepoURL, to: storeURL)
        switch cloneResult {
        case let .success(clonedRepo):
            storeRepo = clonedRepo
            print("clone repo: \(storeURL) success")
            updatePasswordEntityCoreData()
            return true
        case let .failure(error):
            print(error)
            return false
        }
    }
    
    func updatePasswordEntityCoreData() {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PasswordEntity")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
        } catch let error as NSError {
            print(error)
        }

        let fm = FileManager.default
        fm.enumerator(atPath: storeURL.path)?.forEach({ (e) in
            if let e = e as? String, let url = URL(string: e) {
                if url.pathExtension == "gpg" {
                    let entity = PasswordEntity(context: context)
                    entity.name = url.lastPathComponent
                    entity.rawPath = url.path
                }
            }
        })
        do {
            try context.save()
        } catch {
            print("Error with save: \(error)")
        }
    }
    
    func fetchPasswordEntityCoreData() -> [PasswordEntity] {
        let passwordEntityFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "PasswordEntity")
        do {
            let fetchedPasswordEntities = try context.fetch(passwordEntityFetch) as! [PasswordEntity]
            return fetchedPasswordEntities
        } catch {
            fatalError("Failed to fetch employees: \(error)")
        }
    }
    
    func updateRemoteRepo() {
    }
}
