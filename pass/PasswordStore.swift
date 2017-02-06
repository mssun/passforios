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

struct GitCredential {
    
    enum Credential {
        case http(userName: String, password: String)
        case ssh(userName: String, password: String, publicKeyFile: URL, privateKeyFile: URL)
    }
    
    var credential: Credential
    
    func credentialProvider() throws -> GTCredentialProvider {
        return GTCredentialProvider { (_, _, _) -> (GTCredential) in
            let credential: GTCredential?
            switch self.credential {
            case let .http(userName, password):
                print("username \(userName), password \(password)")
                credential = try? GTCredential(userName: userName, password: password)
            case let .ssh(userName, password, publicKeyFile, privateKeyFile):
                print("username \(userName), password \(password), publicKeyFile \(publicKeyFile), privateKeyFile \(privateKeyFile)")
                credential = try? GTCredential(userName: userName, publicKeyURL: publicKeyFile, privateKeyURL: privateKeyFile, passphrase: password)
            }
            return credential ?? GTCredential()
        }
    }
}

class PasswordStore {
    static let shared = PasswordStore()
    
    let storeURL = URL(fileURLWithPath: "\(Globals.shared.documentPath)/password-store")
    let tempStoreURL = URL(fileURLWithPath: "\(Globals.shared.documentPath)/password-store-temp")
    var storeRepository: GTRepository?
    var gitCredential: GitCredential?
    
    let pgp: ObjectivePGP = ObjectivePGP()
    
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext

    
    private init() {
        do {
            if FileManager.default.fileExists(atPath: storeURL.path) {
                try storeRepository = GTRepository.init(url: storeURL)
            }
        } catch {
            print(error)
        }
        if Defaults[.pgpKeyID] != "" {
            pgp.importKeys(fromFile: Globals.shared.secringPath, allowDuplicates: false)
        }
        if Defaults[.gitRepositoryAuthenticationMethod] == "Password" {
            gitCredential = GitCredential(credential: GitCredential.Credential.http(userName: Defaults[.gitRepositoryUsername], password: Defaults[.gitRepositoryPassword]))
        } else if Defaults[.gitRepositoryAuthenticationMethod] == "SSH Key"{
            gitCredential = GitCredential(credential: GitCredential.Credential.ssh(userName: Defaults[.gitRepositoryUsername], password: Defaults[.gitRepositorySSHPrivateKeyPassphrase]!, publicKeyFile: Globals.shared.sshPublicKeyPath, privateKeyFile: Globals.shared.sshPrivateKeyPath))
        } else {
            gitCredential = nil
        }
        
    }
    
    func initPGP(pgpKeyURL: URL, pgpKeyLocalPath: String) throws {
        let pgpData = try Data(contentsOf: pgpKeyURL)
        try pgpData.write(to: URL(fileURLWithPath: pgpKeyLocalPath), options: .atomic)
        pgp.importKeys(fromFile: pgpKeyLocalPath, allowDuplicates: false)
        let key = pgp.keys[0]
        Defaults[.pgpKeyID] = key.keyID!.shortKeyString
        if let gpgUser = key.users[0] as? PGPUser {
            Defaults[.pgpKeyUserID] = gpgUser.userID
        }
    }
    
    
    func cloneRepository(remoteRepoURL: URL,
                         credential: GitCredential,
                         transferProgressBlock: @escaping (UnsafePointer<git_transfer_progress>, UnsafeMutablePointer<ObjCBool>) -> Void,
                         checkoutProgressBlock: @escaping (String?, UInt, UInt) -> Void) throws {
        print("start cloning...")
        let credentialProvider = try credential.credentialProvider()
        let options: [String: Any] = [
            GTRepositoryCloneOptionsCredentialProvider: credentialProvider,
        ]
        storeRepository = try GTRepository.clone(from: remoteRepoURL, toWorkingDirectory: tempStoreURL, options: options, transferProgressBlock:transferProgressBlock, checkoutProgressBlock: checkoutProgressBlock)
        print("clone finish")
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: storeURL.path) {
                try fm.removeItem(at: storeURL)
            }
            try fm.copyItem(at: tempStoreURL, to: storeURL)
            try fm.removeItem(at: tempStoreURL)
        } catch {
            print(error)
        }
        storeRepository = try GTRepository(url: storeURL)
        updatePasswordEntityCoreData()
        gitCredential = credential
    }
    
    func pullRepository(transferProgressBlock: @escaping (UnsafePointer<git_transfer_progress>, UnsafeMutablePointer<ObjCBool>) -> Void) throws {
        print("pullRepoisitory")
        print("start pulling...")
        let credentialProvider = try gitCredential!.credentialProvider()
        let options: [String: Any] = [
            GTRepositoryRemoteOptionsCredentialProvider: credentialProvider
        ]
        let remote = try GTRemote(name: "origin", in: storeRepository!)
        try storeRepository?.pull((storeRepository?.currentBranch())!, from: remote, withOptions: options, progress: transferProgressBlock)
        updatePasswordEntityCoreData()
    }
    
    func updatePasswordEntityCoreData() {
        let passwordEntityFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PasswordEntity")
        let passwordCategoryEntityFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PasswordCategoryEntity")
        let passwordEntityDeleteRequest = NSBatchDeleteRequest(fetchRequest: passwordEntityFetchRequest)
        let passwordCategoryEntityDeleteRequest = NSBatchDeleteRequest(fetchRequest: passwordCategoryEntityFetchRequest)

        do {
            try context.execute(passwordEntityDeleteRequest)
            try context.execute(passwordCategoryEntityDeleteRequest)
        } catch let error as NSError {
            print(error)
        }

        let fm = FileManager.default
        fm.enumerator(atPath: storeURL.path)?.forEach({ (e) in
            if let e = e as? String, let url = URL(string: e) {
                if url.pathExtension == "gpg" {
                    let passwordEntity = PasswordEntity(context: context)
                    let endIndex =  url.lastPathComponent.index(url.lastPathComponent.endIndex, offsetBy: -4)
                    passwordEntity.name = url.lastPathComponent.substring(to: endIndex)
                    passwordEntity.rawPath = "password-store/\(url.path)"
                    let items = url.path.characters.split(separator: "/").map(String.init)
                    for i in 0 ..< items.count - 1 {
                        let passwordCategoryEntity = PasswordCategoryEntity(context: context)
                        passwordCategoryEntity.category = items[i]
                        passwordCategoryEntity.level = Int16(i)
                        passwordCategoryEntity.password = passwordEntity
                    }
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
    
    func fetchPasswordCategoryEntityCoreData(password: PasswordEntity) -> [PasswordCategoryEntity] {
        let passwordCategoryEntityFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PasswordCategoryEntity")
        passwordCategoryEntityFetchRequest.predicate = NSPredicate(format: "password = %@", password)
        passwordCategoryEntityFetchRequest.sortDescriptors = [NSSortDescriptor(key: "level", ascending: true)]
        do {
            let passwordCategoryEntities = try context.fetch(passwordCategoryEntityFetchRequest) as! [PasswordCategoryEntity]
            return passwordCategoryEntities
        } catch {
            fatalError("Failed to fetch employees: \(error)")
        }
    }
    
    func updateRemoteRepo() {
    }
}
