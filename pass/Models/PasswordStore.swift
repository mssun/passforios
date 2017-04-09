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
import SVProgressHUD

struct GitCredential {
    
    enum Credential {
        case http(userName: String, password: String)
        case ssh(userName: String, password: String, publicKeyFile: URL, privateKeyFile: URL, passwordNotSetCallback: (() -> String)? )
    }
    
    var credential: Credential

    func credentialProvider() throws -> GTCredentialProvider {
        return GTCredentialProvider { (_, _, _) -> (GTCredential?) in
            var credential: GTCredential? = nil
            switch self.credential {
            case let .http(userName, password):
                print(Defaults[.gitPasswordAttempts])
                var newPassword: String = password
                if Defaults[.gitPasswordAttempts] != 0 {
                    let sem = DispatchSemaphore(value: 0)
                    DispatchQueue.main.async {
                        SVProgressHUD.dismiss()
                        if var topController = UIApplication.shared.keyWindow?.rootViewController {
                            while let presentedViewController = topController.presentedViewController {
                                topController = presentedViewController
                            }
                            let alert = UIAlertController(title: "Password", message: "Please fill in the password of your Git account.", preferredStyle: UIAlertControllerStyle.alert)
                            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {_ in
                                newPassword = alert.textFields!.first!.text!
                                PasswordStore.shared.gitPassword = newPassword
                                sem.signal()
                            }))
                            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                                Defaults[.gitPasswordAttempts] = -1
                                sem.signal()
                            })
                            alert.addTextField(configurationHandler: {(textField: UITextField!) in
                                textField.text = PasswordStore.shared.gitPassword
                                textField.isSecureTextEntry = true
                            })
                                topController.present(alert, animated: true, completion: nil)
                            }
                    }
                    let _ = sem.wait(timeout: DispatchTime.distantFuture)
                }
                if Defaults[.gitPasswordAttempts] == -1 {
                    Defaults[.gitPasswordAttempts] = 0
                    return nil
                }
                Defaults[.gitPasswordAttempts] += 1
                PasswordStore.shared.gitPassword = newPassword
                credential = try? GTCredential(userName: userName, password: newPassword)
            case let .ssh(userName, password, publicKeyFile, privateKeyFile, passwordNotSetCallback):

                var newPassword:String? = password

                // Check if the private key is encrypted
                let encrypted = try? String(contentsOf: privateKeyFile).contains("ENCRYPTED")

                // Request password if not already set
                if encrypted! && password == "" {
                    newPassword = passwordNotSetCallback!()
                }

                // Save password for the future
                Utils.addPasswordToKeychain(name: "gitSSHPrivateKeyPassphrase", password: newPassword!)

                // nil is expected in case of empty password
                if newPassword == "" {
                    newPassword = nil
                }


                credential = try? GTCredential(userName: userName, publicKeyURL: publicKeyFile, privateKeyURL: privateKeyFile, passphrase: newPassword)
            }
            return credential
        }
    }
}

class PasswordStore {
    static let shared = PasswordStore()
    let storeURL = URL(fileURLWithPath: "\(Globals.repositoryPath)")
    let tempStoreURL = URL(fileURLWithPath: "\(Globals.repositoryPath)-temp")
    
    var storeRepository: GTRepository?
    var gitCredential: GitCredential?
    var pgpKeyID: String?
    var publicKey: PGPKey? {
        didSet {
            if publicKey != nil {
                pgpKeyID = publicKey!.keyID!.shortKeyString
            } else {
                pgpKeyID = nil
            }
        }
    }
    var privateKey: PGPKey?
    
    var gitSignatureForNow: GTSignature {
        get {
            return GTSignature(name: Defaults[.gitUsername]!, email: Defaults[.gitUsername]!+"@passforios", time: Date())!
        }
    }
    
    let pgp: ObjectivePGP = ObjectivePGP()
    
    var pgpKeyPassphrase: String? {
        set {
            Utils.addPasswordToKeychain(name: "pgpKeyPassphrase", password: newValue)
        }
        get {
            return Utils.getPasswordFromKeychain(name: "pgpKeyPassphrase")
        }
    }
    var gitPassword: String? {
        set {
            Utils.addPasswordToKeychain(name: "gitPassword", password: newValue)
        }
        get {
            return Utils.getPasswordFromKeychain(name: "gitPassword")
        }
    }
    
    var gitSSHPrivateKeyPassphrase: String? {
        set {
            Utils.addPasswordToKeychain(name: "gitSSHPrivateKeyPassphrase", password: newValue)
        }
        get {
            return Utils.getPasswordFromKeychain(name: "gitSSHPrivateKeyPassphrase") ?? ""
        }
    }
    
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    var numberOfPasswords : Int {
        return self.fetchPasswordEntityCoreData(withDir: false).count 
    }
    
    var sizeOfRepositoryByteCount : UInt64 {
        let fm = FileManager.default
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
        do {
            if FileManager.default.fileExists(atPath: storeURL.path) {
                try storeRepository = GTRepository.init(url: storeURL)
            }
        } catch {
            print(error)
        }
        initPGPKeys()
        initGitCredential()
    }
    
    enum SSHKeyType {
        case `public`, secret
    }
    
    public func initGitCredential() {
        if Defaults[.gitAuthenticationMethod] == "Password" {
            gitCredential = GitCredential(credential: GitCredential.Credential.http(userName: Defaults[.gitUsername]!, password: Utils.getPasswordFromKeychain(name: "gitPassword") ?? ""))
        } else if Defaults[.gitAuthenticationMethod] == "SSH Key"{
            gitCredential = GitCredential(
                credential: GitCredential.Credential.ssh(
                    userName: Defaults[.gitUsername]!,
                    password: gitSSHPrivateKeyPassphrase ?? "",
                    publicKeyFile: Globals.gitSSHPublicKeyURL,
                    privateKeyFile: Globals.gitSSHPrivateKeyURL,
                    passwordNotSetCallback: nil
                )
            )
        } else {
            gitCredential = nil
        }
    }
    
    public func initGitSSHKey(with armorKey: String, _ keyType: SSHKeyType) throws {
        var keyPath = ""
        switch keyType {
        case .public:
            keyPath = Globals.gitSSHPublicKeyPath
        case .secret:
            keyPath = Globals.gitSSHPrivateKeyPath
        }
        
        try armorKey.write(toFile: keyPath, atomically: true, encoding: .ascii)
    }
    
    public func initPGPKeys() {
        do {
            try initPGPKey(.public)
            try initPGPKey(.secret)
        } catch {
            print(error)
        }
    }
    
    public func initPGPKey(_ keyType: PGPKeyType) throws {
        switch keyType {
        case .public:
            let keyPath = Globals.pgpPublicKeyPath
            self.publicKey = importKey(from: keyPath)
            if self.publicKey == nil {
                throw NSError(domain: "me.mssun.pass.error", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot import the public PGP key."])
            }
        case .secret:
            let keyPath = Globals.pgpPrivateKeyPath
            self.privateKey = importKey(from: keyPath)
            if self.privateKey == nil  {
                throw NSError(domain: "me.mssun.pass.error", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot import the private PGP key."])
            }
        default:
            throw NSError(domain: "me.mssun.pass.error", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot import key: unknown PGP key type."])
        }
    }
    
    public func initPGPKey(from url: URL, keyType: PGPKeyType) throws{
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
    
    public func initPGPKey(with armorKey: String, keyType: PGPKeyType) throws {
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
        let fm = FileManager.default
        if fm.fileExists(atPath: keyPath) {
            if let keys = pgp.importKeys(fromFile: keyPath, allowDuplicates: false) as? [PGPKey] {
                return keys.first
            }
        }
        return nil
    }

    func getPgpPrivateKey() -> PGPKey {
        return pgp.getKeysOf(.secret)[0]
    }
    
    func repositoryExisted() -> Bool {
        let fm = FileManager()
        return fm.fileExists(atPath: Globals.repositoryPath)
    }
    
    func passwordExisted(password: Password) -> Bool {
        print(password.name)
        let passwordEntityFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PasswordEntity")
        do {
            passwordEntityFetchRequest.predicate = NSPredicate(format: "name = %@", password.name)
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
    
    func cloneRepository(remoteRepoURL: URL,
                         credential: GitCredential,
                         transferProgressBlock: @escaping (UnsafePointer<git_transfer_progress>, UnsafeMutablePointer<ObjCBool>) -> Void,
                         checkoutProgressBlock: @escaping (String?, UInt, UInt) -> Void) throws {
        Utils.removeFileIfExists(at: storeURL)
        Utils.removeFileIfExists(at: tempStoreURL)
        
        let credentialProvider = try credential.credentialProvider()
        let options: [String: Any] = [
            GTRepositoryCloneOptionsCredentialProvider: credentialProvider,
        ]
        storeRepository = try GTRepository.clone(from: remoteRepoURL, toWorkingDirectory: tempStoreURL, options: options, transferProgressBlock:transferProgressBlock)
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
        gitCredential = credential
        Defaults[.lastSyncedTime] = Date()
        DispatchQueue.main.async {
            self.updatePasswordEntityCoreData()
            NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
        }
    }
    
    func pullRepository(transferProgressBlock: @escaping (UnsafePointer<git_transfer_progress>, UnsafeMutablePointer<ObjCBool>) -> Void) throws {
        if gitCredential == nil {
            throw NSError(domain: "me.mssun.pass.error", code: 1, userInfo: [NSLocalizedDescriptionKey: "Git Repository is not set."])
        }
        let credentialProvider = try gitCredential!.credentialProvider()
        let options: [String: Any] = [
            GTRepositoryRemoteOptionsCredentialProvider: credentialProvider
        ]
        let remote = try GTRemote(name: "origin", in: storeRepository!)
        try storeRepository?.pull((storeRepository?.currentBranch())!, from: remote, withOptions: options, progress: transferProgressBlock)
        Defaults[.lastSyncedTime] = Date()
        DispatchQueue.main.async {
            self.setAllSynced()
            self.updatePasswordEntityCoreData()
            NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
        }
    }
    
    private func updatePasswordEntityCoreData() {
        deleteCoreData(entityName: "PasswordEntity")
        let fm = FileManager.default
        do {
            var q = try fm.contentsOfDirectory(atPath: self.storeURL.path).filter{
                !$0.hasPrefix(".")
            }.map { (filename) -> PasswordEntity in
                let passwordEntity = NSEntityDescription.insertNewObject(forEntityName: "PasswordEntity", into: context) as! PasswordEntity
                if filename.hasSuffix(".gpg") {
                    passwordEntity.name = filename.substring(to: filename.index(filename.endIndex, offsetBy: -4))
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
                                passwordEntity.name = filename.substring(to: filename.index(filename.endIndex, offsetBy: -4))
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
    
    func getRecentCommits(count: Int) -> [GTCommit] {
        guard storeRepository != nil else {
            return []
        }
        var commits = [GTCommit]()
        do {
            let enumerator = try GTEnumerator(repository: storeRepository!)
            try enumerator.pushSHA(storeRepository!.headReference().targetOID.sha!)
            for _ in 0 ..< count {
                let commit = try enumerator.nextObject(withSuccess: nil)
                commits.append(commit)
            }
        } catch {
            print(error)
            return commits
        }
        return commits
    }
    
    func fetchPasswordEntityCoreData(parent: PasswordEntity?) -> [PasswordEntity] {
        let passwordEntityFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "PasswordEntity")
        do {
            passwordEntityFetch.predicate = NSPredicate(format: "parent = %@", parent ?? 0)
            let fetchedPasswordEntities = try context.fetch(passwordEntityFetch) as! [PasswordEntity]
            return fetchedPasswordEntities.sorted { $0.name!.caseInsensitiveCompare($1.name!) == .orderedAscending }
        } catch {
            fatalError("Failed to fetch passwords: \(error)")
        }
    }
    
    func fetchPasswordEntityCoreData(withDir: Bool) -> [PasswordEntity] {
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
    
    
    func fetchUnsyncedPasswords() -> [PasswordEntity] {
        let passwordEntityFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PasswordEntity")
        passwordEntityFetchRequest.predicate = NSPredicate(format: "synced = %i", 0)
        do {
            let passwordEntities = try context.fetch(passwordEntityFetchRequest) as! [PasswordEntity]
            return passwordEntities
        } catch {
            fatalError("Failed to fetch passwords: \(error)")
        }
    }
    
    func setAllSynced() {
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
    
    func getNumberOfUnsyncedPasswords() -> Int {
        let passwordEntityFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "PasswordEntity")
        do {
            passwordEntityFetchRequest.predicate = NSPredicate(format: "synced = %i", 0)
            return try context.count(for: passwordEntityFetchRequest)
        } catch {
            fatalError("Failed to fetch unsynced passwords: \(error)")
        }
    }
    
    
    func getLatestUpdateInfo(filename: String) -> String {
        guard let blameHunks = try? storeRepository?.blame(withFile: filename, options: nil).hunks,
            let latestCommitTime = blameHunks?.map({
                 $0.finalSignature?.time?.timeIntervalSince1970 ?? 0
            }).max() else {
            return "unknown"
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
            autoFormattedDifference = (dateComponentsFormatter.string(from: diffDate)?.appending(" ago"))!
        }
        return autoFormattedDifference
    }
    
    func updateRemoteRepo() {
    }
    
    func createAddCommitInRepository(message: String, fileData: Data, filename: String, progressBlock: (_ progress: Float) -> Void) -> GTCommit? {
        do {
            try storeRepository?.index().add(fileData, withPath: filename)
            try storeRepository?.index().write()
            let newTree = try storeRepository!.index().writeTree()
            let headReference = try storeRepository!.headReference()
            let commitEnum = try GTEnumerator(repository: storeRepository!)
            try commitEnum.pushSHA(headReference.targetOID.sha!)
            let parent = commitEnum.nextObject() as! GTCommit
            progressBlock(0.5)
            let signature = gitSignatureForNow
            let commit = try storeRepository!.createCommit(with: newTree, message: message, author: signature, committer: signature, parents: [parent], updatingReferenceNamed: headReference.name)
            progressBlock(0.7)
            return commit
        } catch {
            print(error)
        }
        return nil
    }
    
    func createRemoveCommitInRepository(message: String, path: String) -> GTCommit? {
        do {
            try storeRepository?.index().removeFile(path)
            try storeRepository?.index().write()
            let newTree = try storeRepository!.index().writeTree()
            let headReference = try storeRepository!.headReference()
            let commitEnum = try GTEnumerator(repository: storeRepository!)
            try commitEnum.pushSHA(headReference.targetOID.sha!)
            let parent = commitEnum.nextObject() as! GTCommit
            let signature = gitSignatureForNow
            let commit = try storeRepository!.createCommit(with: newTree, message: message, author: signature, committer: signature, parents: [parent], updatingReferenceNamed: headReference.name)
            return commit
        } catch {
            print(error)
        }
        return nil
    }
    
    
    private func getLocalBranch(withName branchName: String) -> GTBranch? {
        do {
            let reference = GTBranch.localNamePrefix().appending(branchName)
            let branches = try storeRepository!.branches(withPrefix: reference)
            return branches[0]
        } catch {
            print(error)
        }
        return nil
    }
    
    func pushRepository(transferProgressBlock: @escaping (UInt32, UInt32, Int, UnsafeMutablePointer<ObjCBool>) -> Void) throws {
        let credentialProvider = try gitCredential!.credentialProvider()
        let options: [String: Any] = [
            GTRepositoryRemoteOptionsCredentialProvider: credentialProvider,
            ]
        let masterBranch = getLocalBranch(withName: "master")!
        let remote = try GTRemote(name: "origin", in: storeRepository!)
        try storeRepository?.push(masterBranch, to: remote, withOptions: options, progress: transferProgressBlock)
    }
    
    func add(password: Password, progressBlock: (_ progress: Float) -> Void) throws {
        progressBlock(0.0)
        guard !passwordExisted(password: password) else {
            throw NSError(domain: "me.mssun.pass.error", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot add password: password duplicated."])
        }
        let passwordEntity = NSEntityDescription.insertNewObject(forEntityName: "PasswordEntity", into: context) as! PasswordEntity
        do {
            let encryptedData = try passwordEntity.encrypt(password: password)
            progressBlock(0.3)
            let saveURL = storeURL.appendingPathComponent("\(password.name).gpg")
            try encryptedData.write(to: saveURL)
            passwordEntity.name = password.name
            passwordEntity.path = "\(password.name).gpg"
            passwordEntity.parent = nil
            passwordEntity.synced = false
            passwordEntity.isDir = false
            try context.save()
            print(saveURL.path)
            let _ = createAddCommitInRepository(message: "Add password for \(passwordEntity.nameWithCategory) to store using Pass for iOS.", fileData: encryptedData, filename: saveURL.lastPathComponent, progressBlock: progressBlock)
            progressBlock(1.0)
            NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
        } catch {
            print(error)
        }
    }
    
    func update(passwordEntity: PasswordEntity, password: Password, progressBlock: (_ progress: Float) -> Void) {
        progressBlock(0.0)
        do {
            let encryptedData = try passwordEntity.encrypt(password: password)
            let saveURL = storeURL.appendingPathComponent(passwordEntity.path!)
            try encryptedData.write(to: saveURL)
            progressBlock(0.3)
            let _ = createAddCommitInRepository(message: "Edit password for \(passwordEntity.nameWithCategory) using Pass for iOS.", fileData: encryptedData, filename: saveURL.lastPathComponent, progressBlock: progressBlock)
            progressBlock(1.0)
            NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
        } catch {
            print(error)
        }
    }
    
    public func delete(passwordEntity: PasswordEntity) {
        Utils.removeFileIfExists(at: storeURL.appendingPathComponent(passwordEntity.path!))
        let _ = createRemoveCommitInRepository(message: "Remove \(passwordEntity.nameWithCategory) from store using Pass for iOS", path: passwordEntity.path!)
        context.delete(passwordEntity)
        do {
            try context.save()
        } catch {
            fatalError("Failed to delete a PasswordEntity: \(error)")
        }
        NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
    }
    
    func saveUpdated(passwordEntity: PasswordEntity) {
        do {
            try context.save()
        } catch {
            fatalError("Failed to save a PasswordEntity: \(error)")
        }
    }
    
    func deleteCoreData(entityName: String) {
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
    
    func updateImage(passwordEntity: PasswordEntity, image: Data?) {
        if image == nil {
            return
        }
        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = context
        privateMOC.perform {
            passwordEntity.image = NSData(data: image!)
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
    
    func erase() {
        publicKey = nil
        privateKey = nil
        Utils.removeFileIfExists(at: storeURL)
        Utils.removeFileIfExists(at: tempStoreURL)

        Utils.removeFileIfExists(atPath: Globals.pgpPublicKeyPath)
        Utils.removeFileIfExists(atPath: Globals.pgpPrivateKeyPath)
        Utils.removeFileIfExists(atPath: Globals.gitSSHPublicKeyPath)
        Utils.removeFileIfExists(atPath: Globals.gitSSHPrivateKeyPath)
        
        Utils.removeAllKeychain()

        
        deleteCoreData(entityName: "PasswordEntity")
        
        Defaults.removeAll()
        storeRepository = nil
        
        NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
        NotificationCenter.default.post(name: .passwordStoreErased, object: nil)
    }
    
    // return the number of discarded commits 
    func reset() throws -> Int {
        // get a list of local commits
        if let localCommits = try getLocalCommits(),
            localCommits.count > 0 {
            // get the oldest local commit
            guard let firstLocalCommit = localCommits.last,
                firstLocalCommit.parents.count == 1,
                let newHead = firstLocalCommit.parents.first else {
                    throw NSError(domain: "me.mssun.pass.error", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot decide how to reset."])
            }
            try self.storeRepository?.reset(to: newHead, resetType: GTRepositoryResetType.hard)
            self.setAllSynced()
            self.updatePasswordEntityCoreData()
            Defaults[.lastSyncedTime] = nil
            
            NotificationCenter.default.post(name: .passwordStoreUpdated, object: nil)
            NotificationCenter.default.post(name: .passwordStoreChangeDiscarded, object: nil)
            return localCommits.count
        } else {
            return 0  // no new commit
        }
    }
    
    func numberOfLocalCommits() -> Int {
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
        // get the remote origin/master branch
        guard let remoteBranches = try storeRepository?.remoteBranches(),
            let index = remoteBranches.index(where: { $0.shortName == "master" })
            else {
                throw NSError(domain: "me.mssun.pass.error", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot find remote branch origin/master."])
        }
        let remoteMasterBranch = remoteBranches[index]
        //print("remoteMasterBranch \(remoteMasterBranch)")
        
        // get a list of local commits
        return try storeRepository?.localCommitsRelative(toRemoteBranch: remoteMasterBranch)
    }
}
