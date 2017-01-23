//
//  PasswordStore.swift
//  pass
//
//  Created by Mingshen Sun on 19/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import Result
import CoreData
import UIKit
import SwiftyUserDefaults
import ObjectiveGit

class PasswordStore {
    static let shared = PasswordStore()
    
    let storeURL = URL(fileURLWithPath: "\(Globals.shared.documentPath)/password-store")
    var storeRepository: GTRepository?
    
    let pgp: ObjectivePGP = ObjectivePGP()
    
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext

    
    private init() {
        do {
            try storeRepository = GTRepository.init(url: storeURL)
        } catch {
            print(error)
        }
        if Defaults[.pgpKeyID] != "" {
            pgp.importKeys(fromFile: Globals.shared.secringPath, allowDuplicates: false)

        }
    }
    
    func initPGP(pgpKeyURL: URL, pgpKeyLocalPath: String) -> Bool {
        do {
            let pgpData = try Data(contentsOf: pgpKeyURL)
            try pgpData.write(to: URL(fileURLWithPath: pgpKeyLocalPath), options: .atomic)
            pgp.importKeys(fromFile: pgpKeyLocalPath, allowDuplicates: false)
            let key = pgp.keys[0]
            Defaults[.pgpKeyID] = key.keyID!.shortKeyString
            if let gpgUser = key.users[0] as? PGPUser {
                Defaults[.pgpKeyUserID] = gpgUser.userID
            }
            return true
        } catch {
            print("error")
            return false
        }
    }
    
    
    func cloneRepository(remoteRepoURL: URL,
                         transferProgressBlock: @escaping (UnsafePointer<git_transfer_progress>, UnsafeMutablePointer<ObjCBool>) -> Void,
                         checkoutProgressBlock: @escaping (String?, UInt, UInt) -> Void) -> Bool {
        print("start cloning remote repo")
        let fm = FileManager.default
        if (storeRepository != nil) {
            print("remove item")
            do {
                try fm.removeItem(at: storeURL)
            } catch let error as NSError {
                print(error.debugDescription)
            }
        }
        do {
            print("start cloning...")
            storeRepository = try GTRepository.clone(from: remoteRepoURL, toWorkingDirectory: storeURL, options: nil, transferProgressBlock:transferProgressBlock, checkoutProgressBlock: checkoutProgressBlock)
            updatePasswordEntityCoreData()
            return true
        } catch {
            storeRepository = nil
            print(error)
            return false
        }
    }
    func pullRepository(transferProgressBlock: @escaping (UnsafePointer<git_transfer_progress>, UnsafeMutablePointer<ObjCBool>) -> Void) -> Bool {
        print("pullRepoisitory")
        do {
            let remote = try GTRemote(name: "origin", in: storeRepository!)
            try storeRepository?.pull((storeRepository?.currentBranch())!, from: remote, withOptions: nil, progress: transferProgressBlock)
            updatePasswordEntityCoreData()
            return true
        } catch {
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
                    let endIndex =  url.lastPathComponent.index(url.lastPathComponent.endIndex, offsetBy: -4)
                    entity.name = url.lastPathComponent.substring(to: endIndex)
                    entity.rawPath = "password-store/\(url.absoluteString)"
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
            return fetchedPasswordEntities.sorted(by: { (p1, p2) -> Bool in
                return p1.name! < p2.name!;
            })
        } catch {
            fatalError("Failed to fetch employees: \(error)")
        }
    }
    
    func updateRemoteRepo() {
    }
}
