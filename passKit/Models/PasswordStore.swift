//
//  PasswordStore.swift
//  pass
//
//  Created by Mingshen Sun on 19/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import CoreData
import UIKit
import SwiftyUserDefaults
import ObjectiveGit
import KeychainAccess

public class PasswordStore {
    public static let shared = PasswordStore()
    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        return dateFormatter
    }()
    
    public let storeURL = URL(fileURLWithPath: "\(Globals.repositoryPath)")
    public let tempStoreURL = URL(fileURLWithPath: "\(Globals.repositoryPath)-temp")

    public var storeRepository: GTRepository?
    
    public var gitSignatureForNow: GTSignature? {
        get {
            let gitSignatureName = SharedDefaults[.gitSignatureName] ?? Globals.gitSignatureDefaultName
            let gitSignatureEmail = SharedDefaults[.gitSignatureEmail] ?? Globals.gitSignatureDefaultEmail
            return GTSignature(name: gitSignatureName, email: gitSignatureEmail, time: Date())
        }
    }
    
    public var gitPassword: String? {
        set {
            AppKeychain.shared.add(string: newValue, for: Globals.gitPassword)
        }
        get {
            return AppKeychain.shared.get(for: Globals.gitPassword)
        }
    }
    
    public var gitSSHPrivateKeyPassphrase: String? {
        set {
            AppKeychain.shared.add(string: newValue, for: Globals.gitSSHPrivateKeyPassphrase)
        }
        get {
            return AppKeychain.shared.get(for: Globals.gitSSHPrivateKeyPassphrase)
        }
    }
    
    private let fm = FileManager.default
    lazy private var context: NSManagedObjectContext = {
        let modelURL = Bundle(identifier: Globals.passKitBundleIdentifier)!.url(forResource: "pass", withExtension: "momd")!
        let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)
        let container = NSPersistentContainer(name: "pass", managedObjectModel: managedObjectModel!)
        if FileManager.default.fileExists(atPath: Globals.documentPath) {
            try! FileManager.default.createDirectory(atPath: Globals.documentPath, withIntermediateDirectories: true, attributes: nil)
        }
        container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: URL(fileURLWithPath: Globals.dbPath))]
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("UnresolvedError".localize("\(error.localizedDescription), \(error.userInfo)"))
            }
        })
        return container.viewContext
    }()
    
    public var numberOfPasswords : Int {
        return self.fetchPasswordEntityCoreData(withDir: false).count
    }
    
    public var sizeOfRepositoryByteCount : UInt64 {
        return (try? fm.allocatedSizeOfDirectoryAtURL(directoryURL: self.storeURL)) ?? 0
    }
    
    public var numberOfLocalCommits: Int {
        return (try? getLocalCommits())?.flatMap { $0.count } ?? 0
    }
    
    public var lastSyncedTime: Date? {
        return SharedDefaults[.lastSyncedTime]
    }
    
    public var numberOfCommits: UInt? {
        return storeRepository?.numberOfCommits(inCurrentBranch: nil)
    }
    
    private init() {
        // Migration
        importExistingKeysIntoKeychain()
        
        do {
            if fm.fileExists(atPath: storeURL.path) {
                try storeRepository = GTRepository.init(url: storeURL)
            }
        } catch {
            print(error)
        }
    }

    private func importExistingKeysIntoKeychain() {
        // App Store update: v0.5.1 -> v0.6.0
        try? KeyFileManager(keyType: PgpKey.PUBLIC, keyPath: Globals.pgpPublicKeyPath).importKeyFromFileSharing()
        try? KeyFileManager(keyType: PgpKey.PRIVATE, keyPath: Globals.pgpPrivateKeyPath).importKeyFromFileSharing()
        try? KeyFileManager(keyType: SshKey.PRIVATE, keyPath: Globals.gitSSHPrivateKeyPath).importKeyFromFileSharing()
        SharedDefaults.remove(.pgpPublicKeyArmor)
        SharedDefaults.remove(.pgpPrivateKeyArmor)
        SharedDefaults.remove(.gitSSHPrivateKeyArmor)
    }
    
    public func initGitSSHKey(with armorKey: String) throws {
        AppKeychain.shared.add(string: armorKey, for: SshKey.PRIVATE.getKeychainKey())
    }
    
    public func repositoryExisted() -> Bool {
        let fm = FileManager()
        return fm.fileExists(atPath: Globals.repositoryPath)
    }
    
    public func passwordExisted(password: Password) -> Bool {
        let passwordEntityFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PasswordEntity")
        do {
            passwordEntityFetchRequest.predicate = NSPredicate(format: "name = %@ and path = %@", password.name, password.url.path)
            let count = try context.count(for: passwordEntityFetchRequest)
            if count > 0 {
                return true
            } else {
                return false
            }
        } catch {
            fatalError("FailedToFetchPasswordEntities".localize(error))
        }
    }
    
    public func passwordEntityExisted(path: String) -> Bool {
        let passwordEntityFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PasswordEntity")
        do {
            passwordEntityFetchRequest.predicate = NSPredicate(format: "path = %@", path)
            let count = try context.count(for: passwordEntityFetchRequest)
            if count > 0 {
                return true
            } else {
                return false
            }
        } catch {
            fatalError("FailedToFetchPasswordEntities".localize(error))
        }
    }
    
    public func getPasswordEntity(by path: String, isDir: Bool) -> PasswordEntity? {
        let passwordEntityFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PasswordEntity")
        do {
            passwordEntityFetchRequest.predicate = NSPredicate(format: "path = %@ and isDir = %@", path, isDir as NSNumber)
            return try context.fetch(passwordEntityFetchRequest).first as? PasswordEntity
        } catch {
            fatalError("FailedToFetchPasswordEntities".localize(error))
        }
    }
    
    public func cloneRepository(remoteRepoURL: URL,
                                credential: GitCredential,
                                branchName: String,
                                requestGitPassword: @escaping (GitCredential.Credential, String?) -> String?,
                                transferProgressBlock: @escaping (UnsafePointer<git_transfer_progress>, UnsafeMutablePointer<ObjCBool>) -> Void,
                                checkoutProgressBlock: @escaping (String?, UInt, UInt) -> Void) throws {
        try? fm.removeItem(at: storeURL)
        try? fm.removeItem(at: tempStoreURL)
        self.gitPassword = nil
        self.gitSSHPrivateKeyPassphrase = nil
        do {
            let credentialProvider = try credential.credentialProvider(requestGitPassword: requestGitPassword)
            let options = [GTRepositoryCloneOptionsCredentialProvider: credentialProvider]
            storeRepository = try GTRepository.clone(from: remoteRepoURL, toWorkingDirectory: tempStoreURL, options: options, transferProgressBlock:transferProgressBlock)
            try fm.moveItem(at: tempStoreURL, to: storeURL)
            storeRepository = try GTRepository(url: storeURL)
            if (try? storeRepository?.currentBranch().name) != branchName {
                try checkoutAndChangeBranch(withName: branchName)
            }
        } catch {
            credential.delete()
            DispatchQueue.main.async {
                SharedDefaults[.lastSyncedTime] = nil
                self.deleteCoreData(entityName: "PasswordEntity")
                NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
            }
            throw(error)
        }
        DispatchQueue.main.async {
            SharedDefaults[.lastSyncedTime] = Date()
            self.updatePasswordEntityCoreData()
            NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
        }
    }
    
    private func checkoutAndChangeBranch(withName localBranchName: String) throws {
        guard let storeRepository = storeRepository else {
            throw AppError.RepositoryNotSet
        }
        let remoteBranchName = "origin/\(localBranchName)"
        guard let remoteBranch = try? storeRepository.lookUpBranch(withName: remoteBranchName, type: .remote, success: nil) else {
            throw AppError.RepositoryRemoteBranchNotFound(remoteBranchName)
        }
        guard let remoteBranchOid = remoteBranch.oid else {
            throw AppError.RepositoryRemoteBranchNotFound(remoteBranchName)
        }
        let localBranch = try storeRepository.createBranchNamed(localBranchName, from: remoteBranchOid, message: nil)
        try localBranch.updateTrackingBranch(remoteBranch)
        let checkoutOptions = GTCheckoutOptions.init(strategy: .force)
        try storeRepository.checkoutReference(localBranch.reference, options: checkoutOptions)
        try storeRepository.moveHEAD(to: localBranch.reference)
    }
    
    public func pullRepository(credential: GitCredential, requestGitPassword: @escaping (GitCredential.Credential, String?) -> String?, transferProgressBlock: @escaping (UnsafePointer<git_transfer_progress>, UnsafeMutablePointer<ObjCBool>) -> Void) throws {
        guard let storeRepository = storeRepository else {
            throw AppError.RepositoryNotSet
        }
        let credentialProvider = try credential.credentialProvider(requestGitPassword: requestGitPassword)
        let options = [GTRepositoryRemoteOptionsCredentialProvider: credentialProvider]
        let remote = try GTRemote(name: "origin", in: storeRepository)
        try storeRepository.pull(storeRepository.currentBranch(), from: remote, withOptions: options, progress: transferProgressBlock)
        DispatchQueue.main.async {
            SharedDefaults[.lastSyncedTime] = Date()
            self.setAllSynced()
            self.updatePasswordEntityCoreData()
            NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
        }
    }
    
    private func updatePasswordEntityCoreData() {
        deleteCoreData(entityName: "PasswordEntity")
        do {
            var q = try fm.contentsOfDirectory(atPath: self.storeURL.path).filter{
                !$0.hasPrefix(".")
                }.map { (filename) -> PasswordEntity in
                    let passwordEntity = NSEntityDescription.insertNewObject(forEntityName: "PasswordEntity", into: context) as! PasswordEntity
                    if filename.hasSuffix(".gpg") {
                        passwordEntity.name = String(filename.prefix(upTo: filename.index(filename.endIndex, offsetBy: -4)))
                    } else {
                        passwordEntity.name = filename
                    }
                    passwordEntity.path = filename
                    passwordEntity.parent = nil
                    return passwordEntity
            }
            while q.count > 0 {
                let e = q.first!
                q.remove(at: 0)
                guard !e.name!.hasPrefix(".") else {
                    continue
                }
                var isDirectory: ObjCBool = false
                let filePath = storeURL.appendingPathComponent(e.path!).path
                if fm.fileExists(atPath: filePath, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        e.isDir = true
                        let files = try fm.contentsOfDirectory(atPath: filePath).map { (filename) -> PasswordEntity in
                            let passwordEntity = NSEntityDescription.insertNewObject(forEntityName: "PasswordEntity", into: context) as! PasswordEntity
                            if filename.hasSuffix(".gpg") {
                                passwordEntity.name = String(filename.prefix(upTo: filename.index(filename.endIndex, offsetBy: -4)))
                            } else {
                                passwordEntity.name = filename
                            }
                            passwordEntity.path = "\(e.path!)/\(filename)"
                            passwordEntity.parent = e
                            return passwordEntity
                        }
                        q += files
                    } else {
                        e.isDir = false
                    }
                }
            }
        } catch {
            print(error)
        }
        self.saveUpdatedContext()
    }
    
    public func getRecentCommits(count: Int) throws -> [GTCommit] {
        guard let storeRepository = storeRepository else {
            return []
        }
        var commits = [GTCommit]()
        let enumerator = try GTEnumerator(repository: storeRepository)
        if let targetOID = try storeRepository.headReference().targetOID {
            try enumerator.pushSHA(targetOID.sha)
        }
        for _ in 0 ..< count {
            if let commit = try? enumerator.nextObject(withSuccess: nil) {
                commits.append(commit)
            }
        }
        return commits
    }
    
    public func fetchPasswordEntityCoreData(parent: PasswordEntity?) -> [PasswordEntity] {
        let passwordEntityFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "PasswordEntity")
        do {
            passwordEntityFetch.predicate = NSPredicate(format: "parent = %@", parent ?? 0)
            let fetchedPasswordEntities = try context.fetch(passwordEntityFetch) as! [PasswordEntity]
            return fetchedPasswordEntities.sorted { $0.name!.caseInsensitiveCompare($1.name!) == .orderedAscending }
        } catch {
            fatalError("FailedToFetchPasswords".localize(error))
        }
    }
    
    public func fetchPasswordEntityCoreData(withDir: Bool) -> [PasswordEntity] {
        let passwordEntityFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "PasswordEntity")
        do {
            if !withDir {
                passwordEntityFetch.predicate = NSPredicate(format: "isDir = false")
            }
            let fetchedPasswordEntities = try context.fetch(passwordEntityFetch) as! [PasswordEntity]
            return fetchedPasswordEntities.sorted { $0.name!.caseInsensitiveCompare($1.name!) == .orderedAscending }
        } catch {
            fatalError("FailedToFetchPasswords".localize(error))
        }
    }
    
    
    public func fetchUnsyncedPasswords() -> [PasswordEntity] {
        let passwordEntityFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PasswordEntity")
        passwordEntityFetchRequest.predicate = NSPredicate(format: "synced = %i", 0)
        do {
            let passwordEntities = try context.fetch(passwordEntityFetchRequest) as! [PasswordEntity]
            return passwordEntities
        } catch {
            fatalError("FailedToFetchPasswords".localize(error))
        }
    }
    
    public func setAllSynced() {
        let passwordEntities = fetchUnsyncedPasswords()
        if passwordEntities.count > 0 {
            for passwordEntity in passwordEntities {
                passwordEntity.synced = true
            }
            self.saveUpdatedContext()
        }
    }
    
    public func getLatestUpdateInfo(filename: String) -> String {
        guard let storeRepository = storeRepository else {
            return "Unknown".localize()
        }
        guard let blameHunks = try? storeRepository.blame(withFile: filename, options: nil).hunks,
            let latestCommitTime = blameHunks.map({
                $0.finalSignature?.time?.timeIntervalSince1970 ?? 0
            }).max() else {
                return "Unknown".localize()
        }
        let lastCommitDate = Date(timeIntervalSince1970: latestCommitTime)
        if Date().timeIntervalSince(lastCommitDate) <= 60 {
            return "JustNow".localize()
        }
        return PasswordStore.dateFormatter.string(from: lastCommitDate)
    }
    
    public func updateRemoteRepo() {
    }
    
    private func gitAdd(path: String) throws {
        guard let storeRepository = storeRepository else {
            throw AppError.RepositoryNotSet
        }
        try storeRepository.index().addFile(path)
        try storeRepository.index().write()
    }
    
    private func gitRm(path: String) throws {
        guard let storeRepository = storeRepository else {
            throw AppError.RepositoryNotSet
        }
        let url = storeURL.appendingPathComponent(path)
        if fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
        }
        try storeRepository.index().removeFile(path)
        try storeRepository.index().write()
    }
    
    private func deleteDirectoryTree(at url: URL) throws {
        var tempURL = storeURL.appendingPathComponent(url.deletingLastPathComponent().path)
        var count = try fm.contentsOfDirectory(atPath: tempURL.path).count
        while count == 0 {
            try fm.removeItem(at: tempURL)
            tempURL.deleteLastPathComponent()
            count = try fm.contentsOfDirectory(atPath: tempURL.path).count
        }
    }
    
    private func createDirectoryTree(at url: URL) throws {
        let tempURL = storeURL.appendingPathComponent(url.deletingLastPathComponent().path)
        try fm.createDirectory(at: tempURL, withIntermediateDirectories: true, attributes: nil)
    }
    
    private func gitMv(from: String, to: String) throws {
        let fromURL = storeURL.appendingPathComponent(from)
        let toURL = storeURL.appendingPathComponent(to)
        try fm.moveItem(at: fromURL, to: toURL)
        try gitAdd(path: to)
        try gitRm(path: from)
    }
    
    private func gitCommit(message: String) throws -> GTCommit? {
        guard let storeRepository = storeRepository else {
            throw AppError.RepositoryNotSet
        }
        let newTree = try storeRepository.index().writeTree()
        let headReference = try storeRepository.headReference()
        let commitEnum = try GTEnumerator(repository: storeRepository)
        try commitEnum.pushSHA(headReference.targetOID!.sha)
        let parent = commitEnum.nextObject() as! GTCommit
        guard let signature = gitSignatureForNow else {
            throw AppError.GitCommit
        }
        let commit = try storeRepository.createCommit(with: newTree, message: message, author: signature, committer: signature, parents: [parent], updatingReferenceNamed: headReference.name)
        return commit
    }
    
    private func getLocalBranch(withName branchName: String) throws -> GTBranch? {
        guard let storeRepository = storeRepository else {
            throw AppError.RepositoryNotSet
        }
        let reference = GTBranch.localNamePrefix().appending(branchName)
        let branches = try storeRepository.branches(withPrefix: reference)
        return branches.first
    }
    
    public func pushRepository(credential: GitCredential, requestGitPassword: @escaping (GitCredential.Credential, String?) -> String?, transferProgressBlock: @escaping (UInt32, UInt32, Int, UnsafeMutablePointer<ObjCBool>) -> Void) throws {
        guard let storeRepository = storeRepository else {
            throw AppError.RepositoryNotSet
        }
        do {
            let credentialProvider = try credential.credentialProvider(requestGitPassword: requestGitPassword)
            let options = [GTRepositoryRemoteOptionsCredentialProvider: credentialProvider]
            if let branch = try getLocalBranch(withName: SharedDefaults[.gitBranchName]) {
                let remote = try GTRemote(name: "origin", in: storeRepository)
                try storeRepository.push(branch, to: remote, withOptions: options, progress: transferProgressBlock)
            }
        } catch {
            throw(error)
        }
    }
    
    private func addPasswordEntities(password: Password) throws -> PasswordEntity? {
        guard !passwordExisted(password: password) else {
            throw AppError.PasswordDuplicated
        }
        
        var passwordURL = password.url
        var previousPathLength = Int.max
        var paths: [String] = []
        while passwordURL.path != "." {
            paths.append(passwordURL.path)
            passwordURL = passwordURL.deletingLastPathComponent()
            // better identify errors before saving a new password
            if passwordURL.path != "." && passwordURL.path.count >= previousPathLength {
                throw AppError.WrongPasswordFilename
            }
            previousPathLength = passwordURL.path.count
        }
        paths.reverse()
        var parentPasswordEntity: PasswordEntity? = nil
        for path in paths {
            let isDir = !path.hasSuffix(".gpg")
            if let passwordEntity = getPasswordEntity(by: path, isDir: isDir) {
                passwordEntity.synced = false
                parentPasswordEntity = passwordEntity
            } else {
                let passwordEntity = NSEntityDescription.insertNewObject(forEntityName: "PasswordEntity", into: self.context) as! PasswordEntity
                let pathURL = URL(string: path.stringByAddingPercentEncodingForRFC3986()!)!
                if isDir {
                    passwordEntity.name = pathURL.lastPathComponent
                } else {
                    passwordEntity.name = pathURL.deletingPathExtension().lastPathComponent
                }
                passwordEntity.path = path
                passwordEntity.parent = parentPasswordEntity
                passwordEntity.synced = false
                passwordEntity.isDir = isDir
                parentPasswordEntity = passwordEntity
            }
        }

        self.saveUpdatedContext()
        return parentPasswordEntity
    }
    
    public func add(password: Password) throws -> PasswordEntity? {
        try createDirectoryTree(at: password.url)
        let newPasswordEntity = try addPasswordEntities(password: password)
        let saveURL = storeURL.appendingPathComponent(password.url.path)
        try self.encrypt(password: password).write(to: saveURL)
        try gitAdd(path: password.url.path)
        let _ = try gitCommit(message: "AddPassword.".localize(password.url.deletingPathExtension().path))
        NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
        return newPasswordEntity
    }
    
    public func delete(passwordEntity: PasswordEntity) throws {
        let deletedFileURL = try passwordEntity.getURL()
        try gitRm(path: deletedFileURL.path)
        try deletePasswordEntities(passwordEntity: passwordEntity)
        try deleteDirectoryTree(at: deletedFileURL)
        let _ = try gitCommit(message: "RemovePassword.".localize(deletedFileURL.deletingPathExtension().path.removingPercentEncoding!))
        NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
    }
    
    public func edit(passwordEntity: PasswordEntity, password: Password) throws -> PasswordEntity? {
        var newPasswordEntity: PasswordEntity? = passwordEntity
        let url = try passwordEntity.getURL()
        
        if password.changed&PasswordChange.content.rawValue != 0 {
            let saveURL = storeURL.appendingPathComponent(url.path)
            try self.encrypt(password: password).write(to: saveURL)
            try gitAdd(path: url.path)
            let _ = try gitCommit(message: "EditPassword.".localize(url.deletingPathExtension().path.removingPercentEncoding!))
            newPasswordEntity = passwordEntity
            newPasswordEntity?.synced = false
            self.saveUpdatedContext()
        }
        
        if password.changed&PasswordChange.path.rawValue != 0 {
            let deletedFileURL = url
            // add
            try createDirectoryTree(at: password.url)
            newPasswordEntity = try addPasswordEntities(password: password)
            
            // mv
            try gitMv(from: deletedFileURL.path, to: password.url.path)
            
            // delete
            try deleteDirectoryTree(at: deletedFileURL)
            try deletePasswordEntities(passwordEntity: passwordEntity)
            let _ = try gitCommit(message: "RenamePassword.".localize(deletedFileURL.deletingPathExtension().path.removingPercentEncoding!, password.url.deletingPathExtension().path.removingPercentEncoding!))
        }
        NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
        return newPasswordEntity
    }
    
    private func deletePasswordEntities(passwordEntity: PasswordEntity) throws {
        var current: PasswordEntity? = passwordEntity
        while current != nil && (current!.children!.count == 0 || !current!.isDir) {
            let parent = current!.parent
            self.context.delete(current!)
            current = parent
        }
        self.saveUpdatedContext()
    }
    
    public func saveUpdatedContext() {
        do {
            try context.save()
        } catch {
            fatalError("FailureToSaveContext".localize(error))
        }
    }
    
    public func deleteCoreData(entityName: String) {
        let deleteFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: deleteFetchRequest)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
            context.reset()
        } catch let error as NSError {
            print(error)
        }
    }
    
    public func updateImage(passwordEntity: PasswordEntity, image: Data?) {
        guard let image = image else {
            return
        }
        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = context
        privateMOC.perform {
            passwordEntity.image = image
            do {
                try privateMOC.save()
                self.context.performAndWait {
                    self.saveUpdatedContext()
                }
            } catch {
                fatalError("FailureToSaveContext".localize(error))
            }
        }
    }
    
    public func erase() {
        // Delete files.
        try? fm.removeItem(at: storeURL)
        try? fm.removeItem(at: tempStoreURL)
        
        // Delete PGP key, SSH key and other secrets from the keychain.
        AppKeychain.shared.removeAllContent()

        // Delete core data.
        deleteCoreData(entityName: "PasswordEntity")
        
        // Delete default settings.
        SharedDefaults.removeAll()
        
        // Clean up variables inside PasswordStore.
        storeRepository = nil
        
        // Delete cache explicitly.
        PasscodeLock.shared.delete()
        PGPAgent.shared.uninitKeys()
        
        // Broadcast.
        NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
        NotificationCenter.default.post(name: .passwordStoreErased, object: nil)
    }
    
    // return the number of discarded commits
    public func reset() throws -> Int {
        guard let storeRepository = storeRepository else {
            throw AppError.RepositoryNotSet
        }
        // get a list of local commits
        if let localCommits = try getLocalCommits(),
            localCommits.count > 0 {
            // get the oldest local commit
            guard let firstLocalCommit = localCommits.last,
                firstLocalCommit.parents.count == 1,
                let newHead = firstLocalCommit.parents.first else {
                    throw AppError.GitReset
            }
            try storeRepository.reset(to: newHead, resetType: .hard)
            self.setAllSynced()
            self.updatePasswordEntityCoreData()
            
            NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
            NotificationCenter.default.post(name: .passwordStoreChangeDiscarded, object: nil)
            return localCommits.count
        } else {
            return 0  // no new commit
        }
    }
    
    
    private func getLocalCommits() throws -> [GTCommit]? {
        guard let storeRepository = storeRepository else {
            throw AppError.RepositoryNotSet
        }
        // get the remote branch
        let remoteBranchName = SharedDefaults[.gitBranchName]
        guard let remoteBranch = try storeRepository.remoteBranches().first(where: { $0.shortName == remoteBranchName }) else {
            throw AppError.RepositoryRemoteBranchNotFound(remoteBranchName)
        }
        // check oid before calling localCommitsRelative
        guard remoteBranch.oid != nil else {
            throw AppError.RepositoryRemoteBranchNotFound(remoteBranchName)
        }
        
        // get a list of local commits
        return try storeRepository.localCommitsRelative(toRemoteBranch: remoteBranch)
    }
    
    public func decrypt(passwordEntity: PasswordEntity, requestPGPKeyPassphrase: () -> String) throws -> Password? {
        let encryptedDataPath = storeURL.appendingPathComponent(passwordEntity.getPath())
        let encryptedData = try Data(contentsOf: encryptedDataPath)
        guard let decryptedData = try PGPAgent.shared.decrypt(encryptedData: encryptedData, requestPGPKeyPassphrase: requestPGPKeyPassphrase) else {
            throw AppError.Decryption
        }
        let plainText = String(data: decryptedData, encoding: .utf8) ?? ""
        let url = try passwordEntity.getURL()
        return Password(name: passwordEntity.getName(), url: url, plainText: plainText)
    }
    
    public func encrypt(password: Password) throws -> Data {
        return try PGPAgent.shared.encrypt(plainData: password.plainData)
    }
    
    public func removeGitSSHKeys() {
        try? fm.removeItem(atPath: Globals.gitSSHPrivateKeyPath)
        Defaults.remove(.gitSSHKeySource)
        Defaults.remove(.gitSSHPrivateKeyArmor)
        Defaults.remove(.gitSSHPrivateKeyURL)
        AppKeychain.shared.removeContent(for: SshKey.PRIVATE.getKeychainKey())
        gitSSHPrivateKeyPassphrase = nil
    }
    
    public func gitSSHKeyImportFromFileSharing() throws {
        try KeyFileManager.PrivateSsh.importKeyFromFileSharing()
    }
}
