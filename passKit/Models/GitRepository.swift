//
//  GitRepository.swift
//  pass
//
//  Created by Mingshen Sun on 1/25/25.
//  Copyright © 2025 Bob Sun. All rights reserved.
//
import ObjectiveGit

public typealias TransferProgressHandler = (UnsafePointer<git_transfer_progress>, UnsafeMutablePointer<ObjCBool>) -> Void
public typealias CheckoutProgressHandler = (String, UInt, UInt) -> Void
public typealias PushProgressHandler = (UInt32, UInt32, Int, UnsafeMutablePointer<ObjCBool>) -> Void
public typealias CloneOptions = [AnyHashable: Any]
public typealias PullOptions = [AnyHashable: Any]
public typealias PushOptions = [String: Any]

public class GitRepository {
    let repository: GTRepository
    var branchName: String = "master"

    public init(with localDir: URL) throws {
        guard FileManager.default.fileExists(atPath: localDir.path) else {
            throw AppError.repositoryNotSet
        }
        try self.repository = GTRepository(url: localDir)
        if let currentBranchName = try? repository.currentBranch().name {
            self.branchName = currentBranchName
        }
    }

    public init(from remoteURL: URL, to workingDir: URL, branchName: String, options: CloneOptions, transferProgressBlock: @escaping TransferProgressHandler, checkoutProgressBlock: @escaping CheckoutProgressHandler) throws {
        self.repository = try GTRepository.clone(
            from: remoteURL,
            toWorkingDirectory: workingDir,
            options: options,
            transferProgressBlock: transferProgressBlock
        )
        self.branchName = branchName
        guard !repository.isHEADUnborn else {
            return
        }
        if (try repository.currentBranch().name) != branchName {
            try checkoutAndChangeBranch(branchName: branchName, progressBlock: checkoutProgressBlock)
        }
    }

    public func checkoutAndChangeBranch(branchName: String, progressBlock: @escaping CheckoutProgressHandler) throws {
        self.branchName = branchName
        if let localBranch = try? repository.lookUpBranch(withName: branchName, type: .local, success: nil) {
            let checkoutOptions = GTCheckoutOptions(strategy: .force, progressBlock: progressBlock)
            try repository.checkoutReference(localBranch.reference, options: checkoutOptions)
            try repository.moveHEAD(to: localBranch.reference)
        } else {
            let remoteBranchName = "origin/\(branchName)"
            let remoteBranch = try repository.lookUpBranch(withName: remoteBranchName, type: .remote, success: nil)
            guard let remoteBranchOid = remoteBranch.oid else {
                throw AppError.repositoryRemoteBranchNotFound(branchName: remoteBranchName)
            }
            let localBranch = try repository.createBranchNamed(branchName, from: remoteBranchOid, message: nil)
            try localBranch.updateTrackingBranch(remoteBranch)
            let checkoutOptions = GTCheckoutOptions(strategy: .force, progressBlock: progressBlock)
            try repository.checkoutReference(localBranch.reference, options: checkoutOptions)
            try repository.moveHEAD(to: localBranch.reference)
        }
    }

    public func pull(
        options: PullOptions,
        transferProgressBlock: @escaping TransferProgressHandler
    ) throws {
        let remote = try GTRemote(name: "origin", in: repository)
        try repository.pull(repository.currentBranch(), from: remote, withOptions: options, progress: transferProgressBlock)
    }

    public func getRecentCommits(count: Int) throws -> [GTCommit] {
        var commits = [GTCommit]()
        let enumerator = try GTEnumerator(repository: repository)
        if let targetOID = try repository.headReference().targetOID {
            try enumerator.pushSHA(targetOID.sha)
        }
        for _ in 0 ..< count {
            if let commit = try? enumerator.nextObject(withSuccess: nil) {
                commits.append(commit)
            }
        }
        return commits
    }

    public func add(path: String) throws {
        try repository.index().addFile(path)
        try repository.index().write()
    }

    public func rm(path: String) throws {
        guard let repoURL = repository.fileURL else {
            throw AppError.repositoryNotSet
        }

        let url = repoURL.appendingPathComponent(path)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try repository.index().removeFile(path)
        try repository.index().write()
    }

    public func mv(from: String, to: String) throws {
        guard let repoURL = repository.fileURL else {
            throw AppError.repositoryNotSet
        }

        let fromURL = repoURL.appendingPathComponent(from)
        let toURL = repoURL.appendingPathComponent(to)
        try FileManager.default.moveItem(at: fromURL, to: toURL)
        try add(path: to)
        try rm(path: from)
    }

    public func commit(name: String, email: String, message: String) throws -> GTCommit {
        guard let signature = GTSignature(name: name, email: email, time: Date()) else {
            throw AppError.gitCreateSignature
        }
        return try commit(signature: signature, message: message)
    }

    public func commit(signature: GTSignature, message: String) throws -> GTCommit {
        let newTree = try repository.index().writeTree()
        if repository.isHEADUnborn {
            return try repository.createCommit(with: newTree, message: message, author: signature, committer: signature, parents: nil, updatingReferenceNamed: "HEAD")
        }
        let headReference = try repository.headReference()
        let commitEnum = try GTEnumerator(repository: repository)
        try commitEnum.pushSHA(headReference.targetOID!.sha)
        guard let parent = commitEnum.nextObject() as? GTCommit else {
            throw AppError.gitCommit
        }
        return try repository.createCommit(with: newTree, message: message, author: signature, committer: signature, parents: [parent], updatingReferenceNamed: headReference.name)
    }

    public func push(
        options: [String: Any],
        transferProgressBlock: @escaping PushProgressHandler
    ) throws {
        let branch = try repository.currentBranch()
        let remote = try GTRemote(name: "origin", in: repository)
        try repository.push(branch, to: remote, withOptions: options, progress: transferProgressBlock)
    }

    public func getLocalCommits() throws -> [GTCommit] {
        let remoteBranchName = "origin/\(branchName)"
        let remoteBranch = try repository.lookUpBranch(withName: remoteBranchName, type: .remote, success: nil)
        return try repository.localCommitsRelative(toRemoteBranch: remoteBranch)
    }

    public func numberOfCommits() -> Int {
        Int(repository.numberOfCommits(inCurrentBranch: nil))
    }

    public func reset() throws {
        let localCommits = try getLocalCommits()
        if localCommits.isEmpty {
            return
        }
        guard let firstLocalCommit = localCommits.last,
              firstLocalCommit.parents.count == 1,
              let newHead = firstLocalCommit.parents.first else {
            throw AppError.gitReset
        }
        try repository.reset(to: newHead, resetType: .hard)
    }

    public func lastCommitDate(path: String) throws -> Date {
        let blameHunks = try repository.blame(withFile: path, options: nil).hunks
        guard let latestCommitTime = blameHunks.map({ $0.finalSignature?.time?.timeIntervalSince1970 ?? 0 }).max() else {
            return Date(timeIntervalSince1970: 0)
        }
        return Date(timeIntervalSince1970: latestCommitTime)
    }
}
