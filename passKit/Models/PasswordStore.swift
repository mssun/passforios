//
//  PasswordStore.swift
//  pass
//
//  Created by Mingshen Sun on 19/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import CoreData
import Foundation
import KeychainAccess
import ObjectiveGit
import SwiftyUserDefaults
import UIKit

public class PasswordStore {
    public static let shared = PasswordStore()
    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        return dateFormatter
    }()

    public var storeURL: URL
    public var tempStoreURL: URL {
        URL(fileURLWithPath: "\(storeURL.path)-temp")
    }

    public var storeRepository: GTRepository?

    public var gitSignatureForNow: GTSignature? {
        let gitSignatureName = Defaults.gitSignatureName ?? Globals.gitSignatureDefaultName
        let gitSignatureEmail = Defaults.gitSignatureEmail ?? Globals.gitSignatureDefaultEmail
        return GTSignature(name: gitSignatureName, email: gitSignatureEmail, time: Date())
    }

    public var gitPassword: String? {
        get {
            AppKeychain.shared.get(for: Globals.gitPassword)
        }
        set {
            AppKeychain.shared.add(string: newValue, for: Globals.gitPassword)
        }
    }

    public var gitSSHPrivateKeyPassphrase: String? {
        get {
            AppKeychain.shared.get(for: Globals.gitSSHPrivateKeyPassphrase)
        }
        set {
            AppKeychain.shared.add(string: newValue, for: Globals.gitSSHPrivateKeyPassphrase)
        }
    }

    private let fileManager = FileManager.default
    private lazy var context: NSManagedObjectContext = {
        let modelURL = Bundle(identifier: Globals.passKitBundleIdentifier)!.url(forResource: "pass", withExtension: "momd")!
        let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)
        let container = NSPersistentContainer(name: "pass", managedObjectModel: managedObjectModel!)
        if FileManager.default.fileExists(atPath: Globals.documentPath) {
            try! FileManager.default.createDirectory(atPath: Globals.documentPath, withIntermediateDirectories: true, attributes: nil)
        }
        container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: URL(fileURLWithPath: Globals.dbPath))]
        container.loadPersistentStores { _, error in
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
        }
        return container.viewContext
    }()

    public var numberOfPasswords: Int {
        fetchPasswordEntityCoreData(withDir: false).count
    }

    public var sizeOfRepositoryByteCount: UInt64 {
        (try? fileManager.allocatedSizeOfDirectoryAtURL(directoryURL: storeURL)) ?? 0
    }

    public var numberOfLocalCommits: Int {
        (try? getLocalCommits()).map(\.count) ?? 0
    }

    public var lastSyncedTime: Date? {
        Defaults.lastSyncedTime
    }

    public var numberOfCommits: UInt? {
        storeRepository?.numberOfCommits(inCurrentBranch: nil)
    }

    init(url: URL = URL(fileURLWithPath: "\(Globals.repositoryPath)")) {
        self.storeURL = url

        // Migration
        importExistingKeysIntoKeychain()

        do {
            if fileManager.fileExists(atPath: storeURL.path) {
                try self.storeRepository = GTRepository(url: storeURL)
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
        Defaults.remove(\.pgpPublicKeyArmor)
        Defaults.remove(\.pgpPrivateKeyArmor)
        Defaults.remove(\.gitSSHPrivateKeyArmor)
    }

    public func repositoryExists() -> Bool {
        fileManager.fileExists(atPath: Globals.repositoryPath)
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

    public func cloneRepository(
        remoteRepoURL: URL,
        branchName: String,
        options: [AnyHashable: Any]? = nil,
        transferProgressBlock: @escaping (UnsafePointer<git_transfer_progress>, UnsafeMutablePointer<ObjCBool>) -> Void = { _, _ in },
        checkoutProgressBlock: @escaping (String, UInt, UInt) -> Void = { _, _, _ in }
    ) throws {
        try? fileManager.removeItem(at: storeURL)
        try? fileManager.removeItem(at: tempStoreURL)
        gitPassword = nil
        gitSSHPrivateKeyPassphrase = nil
        do {
            storeRepository = try GTRepository.clone(
                from: remoteRepoURL,
                toWorkingDirectory: tempStoreURL,
                options: options,
                transferProgressBlock: transferProgressBlock
            )
            try fileManager.moveItem(at: tempStoreURL, to: storeURL)
            storeRepository = try GTRepository(url: storeURL)
            if (try storeRepository?.currentBranch().name) != branchName {
                try checkoutAndChangeBranch(withName: branchName, progressBlock: checkoutProgressBlock)
            }
        } catch {
            Defaults.lastSyncedTime = nil
            DispatchQueue.main.async {
                self.deleteCoreData(entityName: "PasswordEntity")
                NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
            }
            throw (error)
        }
        Defaults.lastSyncedTime = Date()
        DispatchQueue.main.async {
            self.updatePasswordEntityCoreData()
            NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
        }
    }

    private func checkoutAndChangeBranch(withName localBranchName: String, progressBlock: @escaping (String, UInt, UInt) -> Void) throws {
        guard let storeRepository = storeRepository else {
            throw AppError.repositoryNotSet
        }
        let remoteBranchName = "origin/\(localBranchName)"
        let remoteBranch = try storeRepository.lookUpBranch(withName: remoteBranchName, type: .remote, success: nil)
        guard let remoteBranchOid = remoteBranch.oid else {
            throw AppError.repositoryRemoteBranchNotFound(branchName: remoteBranchName)
        }
        let localBranch = try storeRepository.createBranchNamed(localBranchName, from: remoteBranchOid, message: nil)
        try localBranch.updateTrackingBranch(remoteBranch)
        let checkoutOptions = GTCheckoutOptions(strategy: .force, progressBlock: progressBlock)
        try storeRepository.checkoutReference(localBranch.reference, options: checkoutOptions)
        try storeRepository.moveHEAD(to: localBranch.reference)
    }

    public func pullRepository(
        options: [String: Any],
        progressBlock: @escaping (UnsafePointer<git_transfer_progress>, UnsafeMutablePointer<ObjCBool>) -> Void = { _, _ in }
    ) throws {
        guard let storeRepository = storeRepository else {
            throw AppError.repositoryNotSet
        }
        let remote = try GTRemote(name: "origin", in: storeRepository)
        try storeRepository.pull(storeRepository.currentBranch(), from: remote, withOptions: options, progress: progressBlock)
        Defaults.lastSyncedTime = Date()
        setAllSynced()
        DispatchQueue.main.async {
            self.updatePasswordEntityCoreData()
            NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
        }
    }

    private func updatePasswordEntityCoreData() {
        deleteCoreData(entityName: "PasswordEntity")
        do {
            var entities = try fileManager.contentsOfDirectory(atPath: storeURL.path)
                .filter { !$0.hasPrefix(".") }
                .map { filename -> PasswordEntity in
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
            while !entities.isEmpty {
                let entity = entities.first!
                entities.remove(at: 0)
                guard !entity.name!.hasPrefix(".") else {
                    continue
                }
                var isDirectory: ObjCBool = false
                let filePath = storeURL.appendingPathComponent(entity.path!).path
                if fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        entity.isDir = true
                        let files = try fileManager.contentsOfDirectory(atPath: filePath)
                            .filter { !$0.hasPrefix(".") }
                            .map { filename -> PasswordEntity in
                                let passwordEntity = NSEntityDescription.insertNewObject(forEntityName: "PasswordEntity", into: context) as! PasswordEntity
                                if filename.hasSuffix(".gpg") {
                                    passwordEntity.name = String(filename.prefix(upTo: filename.index(filename.endIndex, offsetBy: -4)))
                                } else {
                                    passwordEntity.name = filename
                                }
                                passwordEntity.path = "\(entity.path!)/\(filename)"
                                passwordEntity.parent = entity
                                return passwordEntity
                            }
                        entities += files
                    } else {
                        entity.isDir = false
                    }
                }
            }
        } catch {
            print(error)
        }
        saveUpdatedContext()
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
        if !passwordEntities.isEmpty {
            for passwordEntity in passwordEntities {
                passwordEntity.synced = true
            }
            saveUpdatedContext()
        }
    }

    public func getLatestUpdateInfo(filename: String) -> String {
        guard let storeRepository = storeRepository else {
            return "Unknown".localize()
        }
        guard let blameHunks = try? storeRepository.blame(withFile: filename, options: nil).hunks else {
            return "Unknown".localize()
        }
        guard let latestCommitTime = blameHunks.map({ $0.finalSignature?.time?.timeIntervalSince1970 ?? 0 }).max() else {
            return "Unknown".localize()
        }
        let lastCommitDate = Date(timeIntervalSince1970: latestCommitTime)
        if Date().timeIntervalSince(lastCommitDate) <= 60 {
            return "JustNow".localize()
        }
        return PasswordStore.dateFormatter.string(from: lastCommitDate)
    }

    public func updateRemoteRepo() {}

    private func gitAdd(path: String) throws {
        guard let storeRepository = storeRepository else {
            throw AppError.repositoryNotSet
        }
        try storeRepository.index().addFile(path)
        try storeRepository.index().write()
    }

    private func gitRm(path: String) throws {
        guard let storeRepository = storeRepository else {
            throw AppError.repositoryNotSet
        }
        let url = storeURL.appendingPathComponent(path)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        try storeRepository.index().removeFile(path)
        try storeRepository.index().write()
    }

    private func deleteDirectoryTree(at url: URL) throws {
        var tempURL = storeURL.appendingPathComponent(url.deletingLastPathComponent().path)
        var count = try fileManager.contentsOfDirectory(atPath: tempURL.path).count
        while count == 0 {
            try fileManager.removeItem(at: tempURL)
            tempURL.deleteLastPathComponent()
            count = try fileManager.contentsOfDirectory(atPath: tempURL.path).count
        }
    }

    private func createDirectoryTree(at url: URL) throws {
        let tempURL = storeURL.appendingPathComponent(url.deletingLastPathComponent().path)
        try fileManager.createDirectory(at: tempURL, withIntermediateDirectories: true, attributes: nil)
    }

    private func gitMv(from: String, to: String) throws {
        let fromURL = storeURL.appendingPathComponent(from)
        let toURL = storeURL.appendingPathComponent(to)
        try fileManager.moveItem(at: fromURL, to: toURL)
        try gitAdd(path: to)
        try gitRm(path: from)
    }

    private func gitCommit(message: String) throws -> GTCommit? {
        guard let storeRepository = storeRepository else {
            throw AppError.repositoryNotSet
        }
        let newTree = try storeRepository.index().writeTree()
        let headReference = try storeRepository.headReference()
        let commitEnum = try GTEnumerator(repository: storeRepository)
        try commitEnum.pushSHA(headReference.targetOID!.sha)
        let parent = commitEnum.nextObject() as! GTCommit
        guard let signature = gitSignatureForNow else {
            throw AppError.gitCreateSignature
        }
        let commit = try storeRepository.createCommit(with: newTree, message: message, author: signature, committer: signature, parents: [parent], updatingReferenceNamed: headReference.name)
        return commit
    }

    private func getLocalBranch(withName branchName: String) throws -> GTBranch? {
        guard let storeRepository = storeRepository else {
            throw AppError.repositoryNotSet
        }
        let reference = GTBranch.localNamePrefix().appending(branchName)
        let branches = try storeRepository.branches(withPrefix: reference)
        return branches.first
    }

    public func pushRepository(
        options: [String: Any],
        transferProgressBlock: @escaping (UInt32, UInt32, Int, UnsafeMutablePointer<ObjCBool>) -> Void = { _, _, _, _ in }
    ) throws {
        guard let storeRepository = storeRepository else {
            throw AppError.repositoryNotSet
        }
        if let branch = try getLocalBranch(withName: Defaults.gitBranchName) {
            let remote = try GTRemote(name: "origin", in: storeRepository)
            try storeRepository.push(branch, to: remote, withOptions: options, progress: transferProgressBlock)
        }
        if numberOfLocalCommits != 0 {
            throw AppError.gitPushNotSuccessful
        }
    }

    private func addPasswordEntities(password: Password) throws -> PasswordEntity? {
        guard !passwordExisted(password: password) else {
            throw AppError.passwordDuplicated
        }

        var passwordURL = password.url
        var previousPathLength = Int.max
        var paths: [String] = []
        while passwordURL.path != "." {
            paths.append(passwordURL.path)
            passwordURL = passwordURL.deletingLastPathComponent()
            // better identify errors before saving a new password
            if passwordURL.path != ".", passwordURL.path.count >= previousPathLength {
                throw AppError.wrongPasswordFilename
            }
            previousPathLength = passwordURL.path.count
        }
        paths.reverse()
        var parentPasswordEntity: PasswordEntity?
        for path in paths {
            let isDir = !path.hasSuffix(".gpg")
            if let passwordEntity = getPasswordEntity(by: path, isDir: isDir) {
                passwordEntity.synced = false
                parentPasswordEntity = passwordEntity
            } else {
                let passwordEntity = NSEntityDescription.insertNewObject(forEntityName: "PasswordEntity", into: context) as! PasswordEntity
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

        saveUpdatedContext()
        return parentPasswordEntity
    }

    public func add(password: Password, keyID: String? = nil) throws -> PasswordEntity? {
        try createDirectoryTree(at: password.url)
        let saveURL = storeURL.appendingPathComponent(password.url.path)
        try encrypt(password: password, keyID: keyID).write(to: saveURL)
        try gitAdd(path: password.url.path)
        _ = try gitCommit(message: "AddPassword.".localize(password.url.deletingPathExtension().path))
        let newPasswordEntity = try addPasswordEntities(password: password)
        NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
        return newPasswordEntity
    }

    public func delete(passwordEntity: PasswordEntity) throws {
        let deletedFileURL = try passwordEntity.getURL()
        try gitRm(path: deletedFileURL.path)
        try deletePasswordEntities(passwordEntity: passwordEntity)
        try deleteDirectoryTree(at: deletedFileURL)
        _ = try gitCommit(message: "RemovePassword.".localize(deletedFileURL.deletingPathExtension().path.removingPercentEncoding!))
        NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
    }

    public func edit(passwordEntity: PasswordEntity, password: Password, keyID: String? = nil) throws -> PasswordEntity? {
        var newPasswordEntity: PasswordEntity? = passwordEntity
        let url = try passwordEntity.getURL()

        if password.changed & PasswordChange.content.rawValue != 0 {
            let saveURL = storeURL.appendingPathComponent(url.path)
            try encrypt(password: password, keyID: keyID).write(to: saveURL)
            try gitAdd(path: url.path)
            _ = try gitCommit(message: "EditPassword.".localize(url.deletingPathExtension().path.removingPercentEncoding!))
            newPasswordEntity = passwordEntity
            newPasswordEntity?.synced = false
            saveUpdatedContext()
        }

        if password.changed & PasswordChange.path.rawValue != 0 {
            let deletedFileURL = url
            // add
            try createDirectoryTree(at: password.url)
            newPasswordEntity = try addPasswordEntities(password: password)

            // mv
            try gitMv(from: deletedFileURL.path, to: password.url.path)

            // delete
            try deleteDirectoryTree(at: deletedFileURL)
            try deletePasswordEntities(passwordEntity: passwordEntity)
            _ = try gitCommit(message: "RenamePassword.".localize(deletedFileURL.deletingPathExtension().path.removingPercentEncoding!, password.url.deletingPathExtension().path.removingPercentEncoding!))
        }
        NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
        return newPasswordEntity
    }

    private func deletePasswordEntities(passwordEntity: PasswordEntity) throws {
        var current: PasswordEntity? = passwordEntity
        // swiftformat:disable:next isEmpty
        while current != nil, current!.children!.count == 0 || !current!.isDir {
            let parent = current!.parent
            context.delete(current!)
            current = parent
        }
        saveUpdatedContext()
    }

    public func saveUpdatedContext() {
        do {
            if context.hasChanges {
                try context.save()
            }
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
        try? fileManager.removeItem(at: storeURL)
        try? fileManager.removeItem(at: tempStoreURL)

        // Delete PGP key, SSH key and other secrets from the keychain.
        AppKeychain.shared.removeAllContent()

        // Delete core data.
        deleteCoreData(entityName: "PasswordEntity")

        // Delete default settings.
        Defaults.removeAll()

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
            throw AppError.repositoryNotSet
        }
        // get a list of local commits
        let localCommits = try getLocalCommits()
        if localCommits.isEmpty {
            return 0 // no new commit
        }
        // get the oldest local commit
        guard let firstLocalCommit = localCommits.last,
            firstLocalCommit.parents.count == 1,
            let newHead = firstLocalCommit.parents.first else {
            throw AppError.gitReset
        }
        try storeRepository.reset(to: newHead, resetType: .hard)
        setAllSynced()
        updatePasswordEntityCoreData()

        NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
        NotificationCenter.default.post(name: .passwordStoreChangeDiscarded, object: nil)
        return localCommits.count
    }

    private func getLocalCommits() throws -> [GTCommit] {
        guard let storeRepository = storeRepository else {
            throw AppError.repositoryNotSet
        }
        // get the remote branch
        let remoteBranchName = Defaults.gitBranchName
        guard let remoteBranch = try storeRepository.remoteBranches().first(where: { $0.shortName == remoteBranchName }) else {
            throw AppError.repositoryRemoteBranchNotFound(branchName: remoteBranchName)
        }
        // check oid before calling localCommitsRelative
        guard remoteBranch.oid != nil else {
            throw AppError.repositoryRemoteBranchNotFound(branchName: remoteBranchName)
        }

        // get a list of local commits
        return try storeRepository.localCommitsRelative(toRemoteBranch: remoteBranch)
    }

    public func decrypt(passwordEntity: PasswordEntity, keyID: String? = nil, requestPGPKeyPassphrase: @escaping (String) -> String) throws -> Password {
        let encryptedDataPath = storeURL.appendingPathComponent(passwordEntity.getPath())
        let keyID = keyID ?? findGPGID(from: encryptedDataPath)
        let encryptedData = try Data(contentsOf: encryptedDataPath)
        guard let decryptedData = try PGPAgent.shared.decrypt(encryptedData: encryptedData, keyID: keyID, requestPGPKeyPassphrase: requestPGPKeyPassphrase) else {
            throw AppError.decryption
        }
        let plainText = String(data: decryptedData, encoding: .utf8) ?? ""
        let url = try passwordEntity.getURL()
        return Password(name: passwordEntity.getName(), url: url, plainText: plainText)
    }

    public func encrypt(password: Password, keyID: String? = nil) throws -> Data {
        let encryptedDataPath = storeURL.appendingPathComponent(password.url.path)
        let keyID = keyID ?? findGPGID(from: encryptedDataPath)
        return try PGPAgent.shared.encrypt(plainData: password.plainData, keyID: keyID)
    }

    public func removeGitSSHKeys() {
        try? fileManager.removeItem(atPath: Globals.gitSSHPrivateKeyPath)
        Defaults.remove(\.gitSSHKeySource)
        Defaults.remove(\.gitSSHPrivateKeyArmor)
        Defaults.remove(\.gitSSHPrivateKeyURL)
        AppKeychain.shared.removeContent(for: SshKey.PRIVATE.getKeychainKey())
        gitSSHPrivateKeyPassphrase = nil
    }
}

public func findGPGID(from url: URL) -> String {
    var path = url
    while !FileManager.default.fileExists(atPath: path.appendingPathComponent(".gpg-id").path),
        path.path != "file:///" {
        path = path.deletingLastPathComponent()
    }
    path = path.appendingPathComponent(".gpg-id")

    return (try? String(contentsOf: path))?.trimmed ?? ""
}
