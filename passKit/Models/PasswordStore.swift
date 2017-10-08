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
import ObjectivePGP
import KeychainAccess

public class PasswordStore {
    public static let shared = PasswordStore()
    public let storeURL = URL(fileURLWithPath: "\(Globals.repositoryPath)")
    public let tempStoreURL = URL(fileURLWithPath: "\(Globals.repositoryPath)-temp")
    
    public var storeRepository: GTRepository?
    public var pgpKeyID: String?
    public var publicKey: PGPKey? {
        didSet {
            if publicKey != nil {
                pgpKeyID = publicKey!.keyID.shortKeyString
            } else {
                pgpKeyID = nil
            }
        }
    }
    public var privateKey: PGPKey?
    
    public var gitSignatureForNow: GTSignature {
        get {
            let gitSignatureName = SharedDefaults[.gitSignatureName] ?? Globals.gitSignatureDefaultName
            let gitSignatureEmail = SharedDefaults[.gitSignatureEmail] ?? Globals.gitSignatureDefaultEmail
            return GTSignature(name: gitSignatureName, email: gitSignatureEmail, time: Date())!
        }
    }
    
    public var pgp: ObjectivePGP = ObjectivePGP()
    
    public var pgpKeyPassphrase: String? {
        set {
            Utils.addPasswordToKeychain(name: "pgpKeyPassphrase", password: newValue)
        }
        get {
            return Utils.getPasswordFromKeychain(name: "pgpKeyPassphrase")
        }
    }
    
    public var gitPassword: String? {
        set {
            Utils.addPasswordToKeychain(name: "gitPassword", password: newValue)
        }
        get {
            return Utils.getPasswordFromKeychain(name: "gitPassword")
        }
    }
    
    public var gitSSHPrivateKeyPassphrase: String? {
        set {
            Utils.addPasswordToKeychain(name: "gitSSHPrivateKeyPassphrase", password: newValue)
        }
        get {
            return Utils.getPasswordFromKeychain(name: "gitSSHPrivateKeyPassphrase")
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
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container.viewContext
    }()
    
    public var numberOfPasswords : Int {
        return self.fetchPasswordEntityCoreData(withDir: false).count 
    }
    
    public var sizeOfRepositoryByteCount : UInt64 {
        var size = UInt64(0)
        do {
            if fm.fileExists(atPath: self.storeURL.path) {
                size = try fm.allocatedSizeOfDirectoryAtURL(directoryURL: self.storeURL)
            }
        } catch {
            print(error)
        }
        return size
    }
    
    private init() {
        // File migration to group
        print(Globals.documentPath)
        print(Globals.libraryPath)
        print(Globals.documentPathLegacy)
        print(Globals.libraryPathLegacy)
        migrateIfNeeded()
        backwardCompatibility()
        
        do {
            if fm.fileExists(atPath: storeURL.path) {
                try storeRepository = GTRepository.init(url: storeURL)
            }
            try initPGPKeys()
        } catch {
            print(error)
        }
    }
    
    private func migrateIfNeeded() {
        // migrate happens only if the repository was cloned and pgp keys were set up using earlier versions
        let needMigration = !pgpKeyExists() && !gitSSHKeyExists() && !fm.fileExists(atPath: Globals.repositoryPath) && fm.fileExists(atPath: Globals.repositoryPathLegacy)
        guard needMigration == true else {
            return
        }
        
        do {
            // migrate Defaults
            let userDefaults = UserDefaults()
            for key in Defaults.dictionaryRepresentation().keys {
                if SharedDefaults.value(forKey: key) == nil {
                    SharedDefaults.setValue(userDefaults.value(forKey: key), forKey: key)
                }
            }
            
            // migrate files
            try fm.createDirectory(atPath: Globals.documentPath, withIntermediateDirectories: true, attributes: nil)
            try fm.createDirectory(atPath: Globals.libraryPath, withIntermediateDirectories: true, attributes: nil)
            if fm.fileExists(atPath: Globals.pgpPublicKeyPathLegacy) {
                try fm.moveItem(atPath: Globals.pgpPublicKeyPathLegacy, toPath: Globals.pgpPublicKeyPath)
            }
            if fm.fileExists(atPath: Globals.pgpPrivateKeyPathLegacy) {
                try fm.moveItem(atPath: Globals.pgpPrivateKeyPathLegacy, toPath: Globals.pgpPrivateKeyPath)
            }
            if fm.fileExists(atPath: Globals.gitSSHPrivateKeyPathLegacy) {
                try fm.moveItem(atPath: Globals.gitSSHPrivateKeyPathLegacy, toPath: Globals.gitSSHPrivateKeyPath)
            }
            try fm.moveItem(atPath: Globals.repositoryPathLegacy, toPath: Globals.repositoryPath)
        } catch {
            print("Migration error: \(error)")
        }
        updatePasswordEntityCoreData()
    }
    
    private func backwardCompatibility() {
        // For the newly-introduced isRememberGitCredentialPassphraseOn (20171008)
        if (self.gitPassword != nil || self.gitSSHPrivateKeyPassphrase != nil) && SharedDefaults[.isRememberGitCredentialPassphraseOn] == false {
            SharedDefaults[.isRememberGitCredentialPassphraseOn] = true
        }
    }
    
    enum SSHKeyType {
        case `public`, secret
    }
    
    public func initGitSSHKey(with armorKey: String) throws {
        let keyPath = Globals.gitSSHPrivateKeyPath
        try armorKey.write(toFile: keyPath, atomically: true, encoding: .ascii)
    }
    
    public func initPGPKeys() throws {
        try initPGPKey(.public)
        try initPGPKey(.secret)
    }
    
    public func initPGPKey(_ keyType: PGPPartialKeyType) throws {
        switch keyType {
        case .public:
            let keyPath = Globals.pgpPublicKeyPath
            self.publicKey = importKey(from: keyPath)
            if self.publicKey == nil {
                throw AppError.KeyImportError
            }
        case .secret:
            let keyPath = Globals.pgpPrivateKeyPath
            self.privateKey = importKey(from: keyPath)
            if self.privateKey == nil  {
                throw AppError.KeyImportError
            }
        default:
            throw AppError.UnknownError
        }
    }
    
    public func initPGPKey(from url: URL, keyType: PGPPartialKeyType) throws {
        var pgpKeyLocalPath = ""
        if keyType == .public {
            pgpKeyLocalPath = Globals.pgpPublicKeyPath
        } else {
            pgpKeyLocalPath = Globals.pgpPrivateKeyPath
        }
        let pgpKeyData = try Data(contentsOf: url)
        try pgpKeyData.write(to: URL(fileURLWithPath: pgpKeyLocalPath), options: .atomic)
        try initPGPKey(keyType)
    }
    
    public func initPGPKey(with armorKey: String, keyType: PGPPartialKeyType) throws {
        var pgpKeyLocalPath = ""
        if keyType == .public {
            pgpKeyLocalPath = Globals.pgpPublicKeyPath
        } else {
            pgpKeyLocalPath = Globals.pgpPrivateKeyPath
        }
        try armorKey.write(toFile: pgpKeyLocalPath, atomically: true, encoding: .ascii)
        try initPGPKey(keyType)
    }
    
    
    private func importKey(from keyPath: String) -> PGPKey? {
        if fm.fileExists(atPath: keyPath) {
            let keys = pgp.importKeys(fromFile: keyPath)
            if !keys.isEmpty {
                return keys.first
            }
        }
        return nil
    }

    public func getPgpPrivateKey() -> PGPKey {
        return pgp.keys.filter({$0.secretKey != nil})[0]
    }
    
    public func repositoryExisted() -> Bool {
        let fm = FileManager()
        return fm.fileExists(atPath: Globals.repositoryPath)
    }
    
    public func passwordExisted(password: Password) -> Bool {
        let passwordEntityFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PasswordEntity")
        do {
            passwordEntityFetchRequest.predicate = NSPredicate(format: "name = %@ and path = %@", password.name, password.url!.path)
            let count = try context.count(for: passwordEntityFetchRequest)
            if count > 0 {
                return true
            } else {
                return false
            }
        } catch {
            fatalError("Failed to fetch password entities: \(error)")
        }
        return true
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
            fatalError("Failed to fetch password entities: \(error)")
        }
        return true
    }
    
    public func getPasswordEntity(by path: String, isDir: Bool) -> PasswordEntity? {
        let passwordEntityFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PasswordEntity")
        do {
            passwordEntityFetchRequest.predicate = NSPredicate(format: "path = %@ and isDir = %@", path, isDir as NSNumber)
            return try context.fetch(passwordEntityFetchRequest).first as? PasswordEntity
        } catch {
            fatalError("Failed to fetch password entities: \(error)")
        }
    }
    
    public func cloneRepository(remoteRepoURL: URL,
                         credential: GitCredential,
                         requestGitPassword: @escaping (GitCredential.Credential, String?) -> String?,
                         transferProgressBlock: @escaping (UnsafePointer<git_transfer_progress>, UnsafeMutablePointer<ObjCBool>) -> Void,
                         checkoutProgressBlock: @escaping (String?, UInt, UInt) -> Void) throws {
        Utils.removeFileIfExists(at: storeURL)
        Utils.removeFileIfExists(at: tempStoreURL)
        self.gitPassword = nil
        self.gitSSHPrivateKeyPassphrase = nil
        do {
            let credentialProvider = try credential.credentialProvider(requestGitPassword: requestGitPassword)
            let options = [GTRepositoryCloneOptionsCredentialProvider: credentialProvider]
            storeRepository = try GTRepository.clone(from: remoteRepoURL, toWorkingDirectory: tempStoreURL, options: options, transferProgressBlock:transferProgressBlock)
            if fm.fileExists(atPath: storeURL.path) {
                try fm.removeItem(at: storeURL)
            }
            try fm.moveItem(at: tempStoreURL, to: storeURL)
            storeRepository = try GTRepository(url: storeURL)
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
    
    public func pullRepository(credential: GitCredential, requestGitPassword: @escaping (GitCredential.Credential, String?) -> String?, transferProgressBlock: @escaping (UnsafePointer<git_transfer_progress>, UnsafeMutablePointer<ObjCBool>) -> Void) throws {
        guard let storeRepository = storeRepository else {
            throw AppError.RepositoryNotSetError
        }
        do {
            let credentialProvider = try credential.credentialProvider(requestGitPassword: requestGitPassword)
            let options = [GTRepositoryRemoteOptionsCredentialProvider: credentialProvider]
            let remote = try GTRemote(name: "origin", in: storeRepository)
            try storeRepository.pull(storeRepository.currentBranch(), from: remote, withOptions: options, progress: transferProgressBlock)
        } catch {
            throw(error)
        }
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
        do {
            try context.save()
        } catch {
            print("Error with save: \(error)")
        }
    }
    
    public func getRecentCommits(count: Int) throws -> [GTCommit] {
        guard let storeRepository = storeRepository else {
            return []
        }
        var commits = [GTCommit]()
        let enumerator = try GTEnumerator(repository: storeRepository)
        if let sha = try storeRepository.headReference().targetOID.sha {
            try enumerator.pushSHA(sha)
        }
        for _ in 0 ..< count {
            let commit = try enumerator.nextObject(withSuccess: nil)
            commits.append(commit)
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
            fatalError("Failed to fetch passwords: \(error)")
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
            fatalError("Failed to fetch passwords: \(error)")
        }
    }
    
    
    public func fetchUnsyncedPasswords() -> [PasswordEntity] {
        let passwordEntityFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PasswordEntity")
        passwordEntityFetchRequest.predicate = NSPredicate(format: "synced = %i", 0)
        do {
            let passwordEntities = try context.fetch(passwordEntityFetchRequest) as! [PasswordEntity]
            return passwordEntities
        } catch {
            fatalError("Failed to fetch passwords: \(error)")
        }
    }
    
    public func setAllSynced() {
        let passwordEntities = fetchUnsyncedPasswords()
        for passwordEntity in passwordEntities {
            passwordEntity.synced = true
        }
        do {
            if context.hasChanges {
                try context.save()
            }
        } catch {
            fatalError("Failed to save: \(error)")
        }
    }
    
    public func getNumberOfUnsyncedPasswords() -> Int {
        let passwordEntityFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PasswordEntity")
        do {
            passwordEntityFetchRequest.predicate = NSPredicate(format: "synced = %i", 0)
            return try context.count(for: passwordEntityFetchRequest)
        } catch {
            fatalError("Failed to fetch unsynced passwords: \(error)")
        }
    }
    
    
    public func getLatestUpdateInfo(filename: String) -> String {
        guard let storeRepository = storeRepository else {
            return "Unknown"
        }
        guard let blameHunks = try? storeRepository.blame(withFile: filename, options: nil).hunks,
            let latestCommitTime = blameHunks.map({
                 $0.finalSignature?.time?.timeIntervalSince1970 ?? 0
            }).max() else {
            return "Unknown"
        }
        let lastCommitDate = Date(timeIntervalSince1970: latestCommitTime)
        let currentDate = Date()
        var autoFormattedDifference: String
        if currentDate.timeIntervalSince(lastCommitDate) <= 60 {
            autoFormattedDifference = "Just now"
        } else {
            let diffDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: lastCommitDate, to: currentDate)
            let dateComponentsFormatter = DateComponentsFormatter()
            dateComponentsFormatter.unitsStyle = .full
            dateComponentsFormatter.maximumUnitCount = 2
            dateComponentsFormatter.includesApproximationPhrase = true
            autoFormattedDifference = dateComponentsFormatter.string(from: diffDate)!.appending(" ago")
        }
        return autoFormattedDifference
    }
    
    public func updateRemoteRepo() {
    }
    
    private func gitAdd(path: String) throws {
        guard let storeRepository = storeRepository else {
            throw AppError.RepositoryNotSetError
        }
        try storeRepository.index().addFile(path)
        try storeRepository.index().write()
    }
    
    private func gitRm(path: String) throws {
        guard let storeRepository = storeRepository else {
            throw AppError.RepositoryNotSetError
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
        guard fm.fileExists(atPath: fromURL.path) else {
            print("\(from) not exist")
            return
        }
        try fm.moveItem(at: fromURL, to: toURL)
        try gitAdd(path: to)
        try gitRm(path: from)
    }
    
    private func gitCommit(message: String) throws -> GTCommit? {
        guard let storeRepository = storeRepository else {
            throw AppError.RepositoryNotSetError
        }
        let newTree = try storeRepository.index().writeTree()
        let headReference = try storeRepository.headReference()
        let commitEnum = try GTEnumerator(repository: storeRepository)
        try commitEnum.pushSHA(headReference.targetOID.sha!)
        let parent = commitEnum.nextObject() as! GTCommit
        let signature = gitSignatureForNow
        let commit = try storeRepository.createCommit(with: newTree, message: message, author: signature, committer: signature, parents: [parent], updatingReferenceNamed: headReference.name)
        return commit
    }
    
    private func getLocalBranch(withName branchName: String) throws -> GTBranch? {
        guard let storeRepository = storeRepository else {
            throw AppError.RepositoryNotSetError
        }
        let reference = GTBranch.localNamePrefix().appending(branchName)
        let branches = try storeRepository.branches(withPrefix: reference)
        return branches.first
    }
    
    public func pushRepository(credential: GitCredential, requestGitPassword: @escaping (GitCredential.Credential, String?) -> String?, transferProgressBlock: @escaping (UInt32, UInt32, Int, UnsafeMutablePointer<ObjCBool>) -> Void) throws {
        guard let storeRepository = storeRepository else {
            throw AppError.RepositoryNotSetError
        }
        do {
            let credentialProvider = try credential.credentialProvider(requestGitPassword: requestGitPassword)
            let options = [GTRepositoryRemoteOptionsCredentialProvider: credentialProvider]
            if let masterBranch = try getLocalBranch(withName: "master") {
                let remote = try GTRemote(name: "origin", in: storeRepository)
                try storeRepository.push(masterBranch, to: remote, withOptions: options, progress: transferProgressBlock)
            }
        } catch {
            throw(error)
        }
    }
    
    private func addPasswordEntities(password: Password) throws -> PasswordEntity? {
        guard !passwordExisted(password: password) else {
            throw AppError.PasswordDuplicatedError
        }
        
        var passwordURL = password.url!
        var paths: [String] = []
        while passwordURL.path != "." {
            paths.append(passwordURL.path)
            passwordURL = passwordURL.deletingLastPathComponent()
        }
        paths.reverse()
        var parentPasswordEntity: PasswordEntity? = nil
        for path in paths {
            let isDir = !path.hasSuffix(".gpg")
            if let passwordEntity = getPasswordEntity(by: path, isDir: isDir) {
                print(passwordEntity.path!)
                parentPasswordEntity = passwordEntity
            } else {
                if !isDir {
                    return insertPasswordEntity(name: URL(string: path.stringByAddingPercentEncodingForRFC3986()!)!.deletingPathExtension().lastPathComponent, path: path, parent: parentPasswordEntity, synced: false, isDir: false)
                } else {
                    parentPasswordEntity = insertPasswordEntity(name: URL(string: path.stringByAddingPercentEncodingForRFC3986()!)!.lastPathComponent, path: path, parent: parentPasswordEntity, synced: false, isDir: true)
                }
            }
        }
        return nil
    }
    
    private func insertPasswordEntity(name: String, path: String, parent: PasswordEntity?, synced: Bool = false, isDir: Bool = false) -> PasswordEntity? {
        var ret: PasswordEntity? = nil
        if let passwordEntity = NSEntityDescription.insertNewObject(forEntityName: "PasswordEntity", into: self.context) as? PasswordEntity {
            passwordEntity.name = name
            passwordEntity.path = path
            passwordEntity.parent = parent
            passwordEntity.synced = synced
            passwordEntity.isDir = isDir
            do {
                try self.context.save()
                ret = passwordEntity
            } catch {
                fatalError("Failed to insert a PasswordEntity: \(error)")
            }
        }
        return ret
    }
    
    public func add(password: Password) throws -> PasswordEntity? {
        try createDirectoryTree(at: password.url!)
        let newPasswordEntity = try addPasswordEntities(password: password)
        let saveURL = storeURL.appendingPathComponent(password.url!.path)
        try self.encrypt(password: password).write(to: saveURL)
        try gitAdd(path: password.url!.path)
        let _ = try gitCommit(message: "Add password for \(password.url!.deletingPathExtension().path) to store using Pass for iOS.")
        NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
        return newPasswordEntity
    }
    
    public func delete(passwordEntity: PasswordEntity) throws {
        let deletedFileURL = passwordEntity.getURL()!
        try deleteDirectoryTree(at: passwordEntity.getURL()!)
        try deletePasswordEntities(passwordEntity: passwordEntity)
        try gitRm(path: deletedFileURL.path)
        let _ = try gitCommit(message: "Remove \(deletedFileURL.deletingPathExtension().path.removingPercentEncoding!) from store using Pass for iOS.")
        NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
    }
    
    public func edit(passwordEntity: PasswordEntity, password: Password) throws -> PasswordEntity? {
        var newPasswordEntity: PasswordEntity? = passwordEntity

        if password.changed&PasswordChange.content.rawValue != 0 {
            print("chagne content")
            let saveURL = storeURL.appendingPathComponent(passwordEntity.getURL()!.path)
            try self.encrypt(password: password).write(to: saveURL)
            try gitAdd(path: passwordEntity.getURL()!.path)
            let _ = try gitCommit(message: "Edit password for \(passwordEntity.getURL()!.deletingPathExtension().path.removingPercentEncoding!) to store using Pass for iOS.")
            newPasswordEntity = passwordEntity
        }
        
        if password.changed&PasswordChange.path.rawValue != 0 {
            print("change path")
            let deletedFileURL = passwordEntity.getURL()!
            // add
            try createDirectoryTree(at: password.url!)
            newPasswordEntity = try addPasswordEntities(password: password)
            
            // mv
            try gitMv(from: deletedFileURL.path, to: password.url!.path)
            
            // delete
            try deleteDirectoryTree(at: deletedFileURL)
            try deletePasswordEntities(passwordEntity: passwordEntity)
            let _ = try gitCommit(message: "Rename \(deletedFileURL.deletingPathExtension().path.removingPercentEncoding!) to \(password.url!.deletingPathExtension().path.removingPercentEncoding!) using Pass for iOS.")

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
            do {
                try self.context.save()
            } catch {
                fatalError("Failed to delete a PasswordEntity: \(error)")
            }
        }
    }
    
    public func saveUpdated(passwordEntity: PasswordEntity) {
        do {
            try context.save()
        } catch {
            fatalError("Failed to save a PasswordEntity: \(error)")
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
            passwordEntity.image = NSData(data: image) as Data
            do {
                try privateMOC.save()
                self.context.performAndWait {
                    do {
                        try self.context.save()
                    } catch {
                        fatalError("Failure to save context: \(error)")
                    }
                }
            } catch {
                fatalError("Failure to save context: \(error)")
            }
        }
    }
    
    public func erase() {
        publicKey = nil
        privateKey = nil
        Utils.removeFileIfExists(at: storeURL)
        Utils.removeFileIfExists(at: tempStoreURL)

        Utils.removeFileIfExists(atPath: Globals.pgpPublicKeyPath)
        Utils.removeFileIfExists(atPath: Globals.pgpPrivateKeyPath)
        Utils.removeFileIfExists(atPath: Globals.gitSSHPrivateKeyPath)
        
        Utils.removeAllKeychain()

        deleteCoreData(entityName: "PasswordEntity")
        
        SharedDefaults.removeAll()
        storeRepository = nil
        
        NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
        NotificationCenter.default.post(name: .passwordStoreErased, object: nil)
    }
    
    // return the number of discarded commits 
    public func reset() throws -> Int {
        guard let storeRepository = storeRepository else {
            throw AppError.RepositoryNotSetError
        }
        // get a list of local commits
        if let localCommits = try getLocalCommits(),
            localCommits.count > 0 {
            // get the oldest local commit
            guard let firstLocalCommit = localCommits.last,
                firstLocalCommit.parents.count == 1,
                let newHead = firstLocalCommit.parents.first else {
                    throw AppError.GitResetError
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
    
    public func numberOfLocalCommits() -> Int {
        do {
            if let localCommits = try getLocalCommits() {
                return localCommits.count
            } else {
                return 0
            }
        } catch {
            print(error)
        }
        return 0
    }
    
    private func getLocalCommits() throws -> [GTCommit]? {
        guard let storeRepository = storeRepository else {
            throw AppError.RepositoryNotSetError
        }
        // get the remote origin/master branch
        guard let index = try storeRepository.remoteBranches().index(where: { $0.shortName == "master" }) else {
            throw AppError.RepositoryRemoteMasterNotFoundError
        }
        let remoteMasterBranch = try storeRepository.remoteBranches()[index]
        
        // check oid before calling localCommitsRelative
        guard remoteMasterBranch.oid != nil else {
            throw AppError.RepositoryRemoteMasterNotFoundError
        }
        
        // get a list of local commits
        return try storeRepository.localCommitsRelative(toRemoteBranch: remoteMasterBranch)
    }
    
    
    
    public func decrypt(passwordEntity: PasswordEntity, requestPGPKeyPassphrase: () -> String) throws -> Password? {
        let encryptedDataPath = storeURL.appendingPathComponent(passwordEntity.path!)
        let encryptedData = try Data(contentsOf: encryptedDataPath)
        var passphrase = self.pgpKeyPassphrase
        if passphrase == nil {
            passphrase = requestPGPKeyPassphrase()
        }
        let decryptedData = try PasswordStore.shared.pgp.decryptData(encryptedData, passphrase: passphrase)
        let plainText = String(data: decryptedData, encoding: .utf8) ?? ""
        let escapedPath = passwordEntity.path!.stringByAddingPercentEncodingForRFC3986() ?? ""
        return Password(name: passwordEntity.name!, url: URL(string: escapedPath), plainText: plainText)
    }
    
    public func encrypt(password: Password) throws -> Data {
        let publicKey = pgp.keys.filter({$0.publicKey != nil})
        guard publicKey.count > 0 else {
            throw AppError.PGPPublicKeyNotExistError
        }
        let plainData = password.getPlainData()
        let encryptedData = try pgp.encryptData(plainData, using: Array(publicKey), armored: SharedDefaults[.encryptInArmored])
        return encryptedData
    }
    
    public func removePGPKeys() {
        Utils.removeFileIfExists(atPath: Globals.pgpPublicKeyPath)
        Utils.removeFileIfExists(atPath: Globals.pgpPrivateKeyPath)
        SharedDefaults.remove(.pgpKeySource)
        SharedDefaults.remove(.pgpPublicKeyArmor)
        SharedDefaults.remove(.pgpPrivateKeyArmor)
        SharedDefaults.remove(.pgpPrivateKeyURL)
        SharedDefaults.remove(.pgpPublicKeyURL)
        Utils.removeKeychain(name: ".pgpKeyPassphrase")
        pgp = ObjectivePGP()
        publicKey = nil
        privateKey = nil
    }
    
    public func removeGitSSHKeys() {
        Utils.removeFileIfExists(atPath: Globals.gitSSHPrivateKeyPath)
        Defaults.remove(.gitSSHPrivateKeyArmor)
        Defaults.remove(.gitSSHPrivateKeyURL)
        self.gitSSHPrivateKeyPassphrase = nil
    }
    
    public func gitSSHKeyExists(inFileSharing: Bool = false) -> Bool {
        if inFileSharing == false {
            return fm.fileExists(atPath: Globals.gitSSHPrivateKeyPath)
        } else {
            return fm.fileExists(atPath: Globals.iTunesFileSharingSSHPrivate)
        }
    }
    
    public func pgpKeyExists(inFileSharing: Bool = false) -> Bool {
        if inFileSharing == false {
            return fm.fileExists(atPath: Globals.pgpPublicKeyPath) && fm.fileExists(atPath: Globals.pgpPrivateKeyPath)
        } else {
            return fm.fileExists(atPath: Globals.iTunesFileSharingPGPPublic) && fm.fileExists(atPath: Globals.iTunesFileSharingPGPPrivate)
        }
    }
    
    public func gitSSHKeyImportFromFileSharing() {
        do {
            try fm.moveItem(atPath: Globals.iTunesFileSharingSSHPrivate, toPath: Globals.gitSSHPrivateKeyPath)
        } catch {
            print(error)
        }
    }

    public func pgpKeyImportFromFileSharing() {
        do {
            try fm.moveItem(atPath: Globals.iTunesFileSharingPGPPublic, toPath: Globals.pgpPublicKeyPath)
            try fm.moveItem(atPath: Globals.iTunesFileSharingPGPPrivate, toPath: Globals.pgpPrivateKeyPath)
        } catch {
            print(error)
        }
    }
}
