//
//  PasswordStore.swift
//  passKit
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
    private lazy var context: NSManagedObjectContext = PersistenceController.shared.viewContext()

    public var numberOfPasswords: Int {
        PasswordEntity.totalNumber(in: context)
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

    public var lastSyncedTimeString: String {
        guard let date = lastSyncedTime else {
            return "SyncAgain?".localize()
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    public var numberOfCommits: UInt? {
        storeRepository?.numberOfCommits(inCurrentBranch: nil)
    }

    init(url: URL = Globals.repositoryURL) {
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
        try? KeyFileManager(keyType: PGPKey.PUBLIC, keyPath: Globals.pgpPublicKeyPath).importKeyFromFileSharing()
        try? KeyFileManager(keyType: PGPKey.PRIVATE, keyPath: Globals.pgpPrivateKeyPath).importKeyFromFileSharing()
        try? KeyFileManager(keyType: SSHKey.PRIVATE, keyPath: Globals.gitSSHPrivateKeyPath).importKeyFromFileSharing()
        Defaults.remove(\.pgpPublicKeyArmor)
        Defaults.remove(\.pgpPrivateKeyArmor)
        Defaults.remove(\.gitSSHPrivateKeyArmor)
    }

    public func repositoryExists() -> Bool {
        fileManager.fileExists(atPath: Globals.repositoryURL.path)
    }

    public func passwordExisted(password: Password) -> Bool {
        PasswordEntity.exists(password: password, in: context)
    }

    public func getPasswordEntity(by path: String, isDir: Bool) -> PasswordEntity? {
        PasswordEntity.fetch(by: path, isDir: isDir, in: context)
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
                self.deleteCoreData()
                NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
            }
            throw (error)
        }
        Defaults.lastSyncedTime = Date()
        DispatchQueue.main.async {
            self.deleteCoreData()
            self.initPasswordEntityCoreData()
            NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
        }
    }

    private func checkoutAndChangeBranch(withName localBranchName: String, progressBlock: @escaping (String, UInt, UInt) -> Void) throws {
        guard let storeRepository else {
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
        guard let storeRepository else {
            throw AppError.repositoryNotSet
        }
        let remote = try GTRemote(name: "origin", in: storeRepository)
        try storeRepository.pull(storeRepository.currentBranch(), from: remote, withOptions: options, progress: progressBlock)
        Defaults.lastSyncedTime = Date()
        setAllSynced()
        DispatchQueue.main.async {
            self.deleteCoreData()
            self.initPasswordEntityCoreData()
            NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
        }
    }

    private func initPasswordEntityCoreData() {
        PasswordEntity.initPasswordEntityCoreData(url: storeURL, in: context)
        saveUpdatedContext()
    }

    public func getRecentCommits(count: Int) throws -> [GTCommit] {
        guard let storeRepository else {
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
        PasswordEntity.fetch(by: parent, in: context)
    }

    public func fetchPasswordEntityCoreData(withDir _: Bool) -> [PasswordEntity] {
        PasswordEntity.fetchAllPassword(in: context)
    }

    public func fetchUnsyncedPasswords() -> [PasswordEntity] {
        PasswordEntity.fetchUnsynced(in: context)
    }

    public func fetchPasswordEntity(with path: String) -> PasswordEntity? {
        PasswordEntity.fetch(by: path, in: context)
    }

    public func setAllSynced() {
        _ = PasswordEntity.updateAllToSynced(in: context)
        saveUpdatedContext()
    }

    public func getLatestUpdateInfo(path: String) -> String {
        guard let storeRepository else {
            return "Unknown".localize()
        }
        guard let blameHunks = try? storeRepository.blame(withFile: path, options: nil).hunks else {
            return "Unknown".localize()
        }
        guard let latestCommitTime = blameHunks.map({ $0.finalSignature?.time?.timeIntervalSince1970 ?? 0 }).max() else {
            return "Unknown".localize()
        }
        let lastCommitDate = Date(timeIntervalSince1970: latestCommitTime)
        if Date().timeIntervalSince(lastCommitDate) <= 60 {
            return "JustNow".localize()
        }
        return Self.dateFormatter.string(from: lastCommitDate)
    }

    private func gitAdd(path: String) throws {
        guard let storeRepository else {
            throw AppError.repositoryNotSet
        }
        try storeRepository.index().addFile(path)
        try storeRepository.index().write()
    }

    private func gitRm(path: String) throws {
        guard let storeRepository else {
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
        var tempURL = url.deletingLastPathComponent()
        while try fileManager.contentsOfDirectory(atPath: tempURL.path).isEmpty {
            try fileManager.removeItem(at: tempURL)
            tempURL.deleteLastPathComponent()
        }
    }

    private func createDirectoryTree(at url: URL) throws {
        let tempURL = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: tempURL, withIntermediateDirectories: true)
    }

    private func gitMv(from: String, to: String) throws {
        let fromURL = storeURL.appendingPathComponent(from)
        let toURL = storeURL.appendingPathComponent(to)
        try fileManager.moveItem(at: fromURL, to: toURL)
        try gitAdd(path: to)
        try gitRm(path: from)
    }

    private func gitCommit(message: String) throws -> GTCommit? {
        guard let storeRepository else {
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
        return try storeRepository.createCommit(with: newTree, message: message, author: signature, committer: signature, parents: [parent], updatingReferenceNamed: headReference.name)
    }

    private func getLocalBranch(withName branchName: String) throws -> GTBranch? {
        guard let storeRepository else {
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
        guard let storeRepository else {
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

        var paths: [String] = []
        var path = password.path
        while !path.isEmpty {
            paths.append(path)
            path = (path as NSString).deletingLastPathComponent
        }

        var parentPasswordEntity: PasswordEntity?
        for (index, path) in paths.reversed().enumerated() {
            if index == paths.count - 1 {
                let passwordEntity = PasswordEntity.insert(name: password.name, path: path, isDir: false, into: context)
                passwordEntity.parent = parentPasswordEntity
                parentPasswordEntity = passwordEntity
            } else {
                if let passwordEntity = PasswordEntity.fetch(by: path, isDir: true, in: context) {
                    passwordEntity.isSynced = false
                    parentPasswordEntity = passwordEntity
                } else {
                    let name = (path as NSString).lastPathComponent
                    let passwordEntity = PasswordEntity.insert(name: name, path: path, isDir: true, into: context)
                    passwordEntity.parent = parentPasswordEntity
                    parentPasswordEntity = passwordEntity
                }
            }
        }
        saveUpdatedContext()
        return parentPasswordEntity
    }

    public func add(password: Password, keyID: String? = nil) throws -> PasswordEntity? {
        let saveURL = storeURL.appendingPathComponent(password.path)
        try createDirectoryTree(at: saveURL)
        try encrypt(password: password, keyID: keyID).write(to: saveURL)
        try gitAdd(path: password.path)
        _ = try gitCommit(message: "AddPassword.".localize(password.path))
        let newPasswordEntity = try addPasswordEntities(password: password)
        NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
        return newPasswordEntity
    }

    public func delete(passwordEntity: PasswordEntity) throws {
        let deletedFileURL = storeURL.appendingPathComponent(passwordEntity.path)
        try gitRm(path: passwordEntity.path)
        try deletePasswordEntities(passwordEntity: passwordEntity)
        try deleteDirectoryTree(at: deletedFileURL)
        _ = try gitCommit(message: "RemovePassword.".localize(passwordEntity.path))
        NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
    }

    public func edit(passwordEntity: PasswordEntity, password: Password, keyID: String? = nil) throws -> PasswordEntity? {
        var newPasswordEntity: PasswordEntity? = passwordEntity
        let url = storeURL.appendingPathComponent(passwordEntity.path)

        if password.changed & PasswordChange.content.rawValue != 0 {
            try encrypt(password: password, keyID: keyID).write(to: url)
            try gitAdd(path: password.path)
            _ = try gitCommit(message: "EditPassword.".localize(passwordEntity.path))
            newPasswordEntity = passwordEntity
            newPasswordEntity?.isSynced = false
        }

        if password.changed & PasswordChange.path.rawValue != 0 {
            let deletedFileURL = url
            // add
            let newFileURL = storeURL.appendingPathComponent(password.path)
            try createDirectoryTree(at: newFileURL)
            newPasswordEntity = try addPasswordEntities(password: password)

            // mv
            try gitMv(from: passwordEntity.path, to: password.path)

            // delete
            try deleteDirectoryTree(at: deletedFileURL)
            try deletePasswordEntities(passwordEntity: passwordEntity)
            _ = try gitCommit(message: "RenamePassword.".localize(passwordEntity.path, password.path))
        }
        saveUpdatedContext()
        NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
        return newPasswordEntity
    }

    private func deletePasswordEntities(passwordEntity: PasswordEntity) throws {
        PasswordEntity.deleteRecursively(entity: passwordEntity, in: context)
        saveUpdatedContext()
    }

    public func saveUpdatedContext() {
        PersistenceController.shared.save()
    }

    public func deleteCoreData() {
        PasswordEntity.deleteAll(in: context)
        PersistenceController.shared.save()
    }

    public func eraseStoreData() {
        // Delete files.
        try? fileManager.removeItem(at: storeURL)
        try? fileManager.removeItem(at: tempStoreURL)

        // Delete core data.
        deleteCoreData()

        // Clean up variables inside PasswordStore.
        storeRepository = nil

        // Broadcast.
        NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
        NotificationCenter.default.post(name: .passwordStoreErased, object: nil)
    }

    public func erase() {
        eraseStoreData()

        // Delete PGP key, SSH key and other secrets from the keychain.
        AppKeychain.shared.removeAllContent()

        // Delete default settings.
        Defaults.removeAll()

        // Delete cache explicitly.
        PasscodeLock.shared.delete()
        PGPAgent.shared.uninitKeys()
    }

    // return the number of discarded commits
    public func reset() throws -> Int {
        guard let storeRepository else {
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
        deleteCoreData()
        initPasswordEntityCoreData()

        NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
        NotificationCenter.default.post(name: .passwordStoreChangeDiscarded, object: nil)
        return localCommits.count
    }

    private func getLocalCommits() throws -> [GTCommit] {
        guard let storeRepository else {
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
        let url = storeURL.appendingPathComponent(passwordEntity.path)
        let encryptedData = try Data(contentsOf: url)
        let data: Data? = try {
            if Defaults.isEnableGPGIDOn {
                let keyID = keyID ?? findGPGID(from: url)
                return try PGPAgent.shared.decrypt(encryptedData: encryptedData, keyID: keyID, requestPGPKeyPassphrase: requestPGPKeyPassphrase)
            }
            return try PGPAgent.shared.decrypt(encryptedData: encryptedData, requestPGPKeyPassphrase: requestPGPKeyPassphrase)
        }()
        guard let decryptedData = data else {
            throw AppError.decryption
        }
        let plainText = String(data: decryptedData, encoding: .utf8) ?? ""
        return Password(name: passwordEntity.name, path: passwordEntity.path, plainText: plainText)
    }

    public func decrypt(path: String, keyID: String? = nil, requestPGPKeyPassphrase: @escaping (String) -> String) throws -> Password {
        guard let passwordEntity = fetchPasswordEntity(with: path) else {
            throw AppError.decryption
        }
        if Defaults.isEnableGPGIDOn {
            return try decrypt(passwordEntity: passwordEntity, keyID: keyID, requestPGPKeyPassphrase: requestPGPKeyPassphrase)
        }
        return try decrypt(passwordEntity: passwordEntity, requestPGPKeyPassphrase: requestPGPKeyPassphrase)
    }

    public func encrypt(password: Password, keyID: String? = nil) throws -> Data {
        let encryptedDataPath = storeURL.appendingPathComponent(password.path)
        let keyID = keyID ?? findGPGID(from: encryptedDataPath)
        if Defaults.isEnableGPGIDOn {
            return try PGPAgent.shared.encrypt(plainData: password.plainData, keyID: keyID)
        }
        return try PGPAgent.shared.encrypt(plainData: password.plainData)
    }

    public func removeGitSSHKeys() {
        try? fileManager.removeItem(atPath: Globals.gitSSHPrivateKeyPath)
        Defaults.remove(\.gitSSHKeySource)
        Defaults.remove(\.gitSSHPrivateKeyArmor)
        Defaults.remove(\.gitSSHPrivateKeyURL)
        AppKeychain.shared.removeContent(for: SSHKey.PRIVATE.getKeychainKey())
        gitSSHPrivateKeyPassphrase = nil
    }
}

func findGPGID(from url: URL) -> String {
    var path = url
    while !FileManager.default.fileExists(atPath: path.appendingPathComponent(".gpg-id").path),
          path.path != "file:///" {
        path = path.deletingLastPathComponent()
    }
    path = path.appendingPathComponent(".gpg-id")

    return (try? String(contentsOf: path))?.trimmed ?? ""
}
