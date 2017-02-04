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
    var storeRepository: GTRepository?
    var gitCredential: GitCredential?
    
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
        if Defaults[.gitRepositoryAuthenticationMethod] == "Password" {
            gitCredential = GitCredential(credential: GitCredential.Credential.http(userName: Defaults[.gitRepositoryUsername], password: Defaults[.gitRepositoryPassword]))
        } else if Defaults[.gitRepositoryAuthenticationMethod] == "SSH Key"{
            gitCredential = GitCredential(credential: GitCredential.Credential.ssh(userName: Defaults[.gitRepositoryUsername], password: Defaults[.gitRepositorySSHPrivateKeyPassphrase]!, publicKeyFile: Globals.shared.sshPublicKeyPath, privateKeyFile: Globals.shared.sshPrivateKeyPath))
        } else {
            gitCredential = nil
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
                         credential: GitCredential,
                         transferProgressBlock: @escaping (UnsafePointer<git_transfer_progress>, UnsafeMutablePointer<ObjCBool>) -> Void,
                         checkoutProgressBlock: @escaping (String?, UInt, UInt) -> Void) throws {
        print("start cloning remote repo: \(remoteRepoURL)")
        let fm = FileManager.default
        if (storeRepository != nil) {
            print("remove item")
            do {
                try fm.removeItem(at: storeURL)
            } catch let error as NSError {
                print(error.debugDescription)
            }
        }
        print("start cloning...")
        let credentialProvider = try credential.credentialProvider()
        let options: [String: Any] = [
            GTRepositoryCloneOptionsCredentialProvider: credentialProvider,
        ]
        storeRepository = try GTRepository.clone(from: remoteRepoURL, toWorkingDirectory: storeURL, options: options, transferProgressBlock:transferProgressBlock, checkoutProgressBlock: checkoutProgressBlock)
        print("clone finish")
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
