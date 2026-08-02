//
//  GitRepository.swift
//  pass
//
//  Created by Mingshen Sun on 1/25/25.
//  Copyright © 2025 Bob Sun. All rights reserved.
//
import ObjectiveGit

// The only place, together with `GitCredential.swift`, that knows about the git
// backend. Everything crossing this boundary is a value type from
// `GitTypes.swift`.

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

    public init(from remoteURL: URL, to workingDir: URL, branchName: String, options: GitCredentialOptions = GitCredentialOptions(), transferProgressBlock: @escaping TransferProgressHandler, checkoutProgressBlock: @escaping CheckoutProgressHandler) throws {
        self.repository = try GTRepository.clone(
            from: remoteURL,
            toWorkingDirectory: workingDir,
            options: options.backendOptions,
            transferProgressBlock: backendBlock(transferProgressBlock)
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
            let checkoutOptions = GTCheckoutOptions(strategy: .force, progressBlock: backendBlock(progressBlock))
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
            let checkoutOptions = GTCheckoutOptions(strategy: .force, progressBlock: backendBlock(progressBlock))
            try repository.checkoutReference(localBranch.reference, options: checkoutOptions)
            try repository.moveHEAD(to: localBranch.reference)
        }
    }

    public func pull(
        options: GitCredentialOptions,
        transferProgressBlock: @escaping TransferProgressHandler
    ) throws {
        let remote = try GTRemote(name: "origin", in: repository)
        try repository.pull(repository.currentBranch(), from: remote, withOptions: options.backendOptions, progress: backendBlock(transferProgressBlock))
    }

    public func getRecentCommits(count: Int) throws -> [GitCommit] {
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
        return commits.map(GitCommit.init)
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

    public func commit(name: String, email: String, message: String) throws -> GitCommit {
        try commit(signature: GitSignature(name: name, email: email), message: message)
    }

    public func commit(signature: GitSignature, message: String) throws -> GitCommit {
        guard let signature = signature.backendSignature else {
            throw AppError.gitCreateSignature
        }
        let newTree = try repository.index().writeTree()
        if repository.isHEADUnborn {
            return GitCommit(try repository.createCommit(with: newTree, message: message, author: signature, committer: signature, parents: nil, updatingReferenceNamed: "HEAD"))
        }
        let headReference = try repository.headReference()
        let commitEnum = try GTEnumerator(repository: repository)
        try commitEnum.pushSHA(headReference.targetOID!.sha)
        guard let parent = commitEnum.nextObject() as? GTCommit else {
            throw AppError.gitCommit
        }
        return GitCommit(try repository.createCommit(with: newTree, message: message, author: signature, committer: signature, parents: [parent], updatingReferenceNamed: headReference.name))
    }

    public func push(
        options: GitCredentialOptions,
        transferProgressBlock: @escaping PushProgressHandler
    ) throws {
        let branch = try repository.currentBranch()
        let remote = try GTRemote(name: "origin", in: repository)
        try repository.push(branch, to: remote, withOptions: options.backendOptions, progress: backendBlock(transferProgressBlock))
    }

    public func getLocalCommits() throws -> [GitCommit] {
        try localCommits().map(GitCommit.init)
    }

    private func localCommits() throws -> [GTCommit] {
        let remoteBranchName = "origin/\(branchName)"
        let remoteBranch = try repository.lookUpBranch(withName: remoteBranchName, type: .remote, success: nil)
        return try repository.localCommitsRelative(toRemoteBranch: remoteBranch)
    }

    public func numberOfCommits() -> Int {
        Int(repository.numberOfCommits(inCurrentBranch: nil))
    }

    public func reset() throws {
        let localCommits = try localCommits()
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

/// Details the git backend attaches to the errors it throws.
public enum GitError {
    /// Paths that could not be merged, if `error` reports a merge conflict.
    public static func mergeConflictPaths(in error: Error) -> [String]? {
        (error as NSError).userInfo[GTPullMergeConflictedFiles] as? [String]
    }
}

// MARK: - Bridging between the value types and the git backend

extension GitSignature {
    var backendSignature: GTSignature? {
        GTSignature(name: name, email: email, time: time)
    }

    /// Whether the git backend accepts this name and email.
    public var isValid: Bool {
        backendSignature != nil
    }

    init?(_ signature: GTSignature?) {
        guard let signature, let name = signature.name, let email = signature.email else {
            return nil
        }
        self.init(name: name, email: email, time: signature.time ?? Date(timeIntervalSince1970: 0))
    }
}

extension GitCommit {
    init(_ commit: GTCommit) {
        self.init(
            sha: commit.sha,
            message: commit.message,
            date: commit.commitDate,
            author: GitSignature(commit.author)
        )
    }
}

extension GitTransferProgress {
    init(_ progress: git_transfer_progress) {
        self.init(
            receivedObjects: progress.received_objects,
            indexedObjects: progress.indexed_objects,
            totalObjects: progress.total_objects,
            receivedBytes: progress.received_bytes
        )
    }
}

/// Adapts a progress handler to the block signature ObjectiveGit expects.
private func backendBlock(_ handler: @escaping TransferProgressHandler) -> (UnsafePointer<git_transfer_progress>, UnsafeMutablePointer<ObjCBool>) -> Void {
    { progress, stop in
        var shouldStop = false
        handler(GitTransferProgress(progress.pointee), &shouldStop)
        stop.pointee = ObjCBool(shouldStop)
    }
}

private func backendBlock(_ handler: @escaping PushProgressHandler) -> (UInt32, UInt32, Int, UnsafeMutablePointer<ObjCBool>) -> Void {
    { current, total, bytes, stop in
        var shouldStop = false
        handler(GitPushProgress(current: current, total: total, bytes: bytes), &shouldStop)
        stop.pointee = ObjCBool(shouldStop)
    }
}

private func backendBlock(_ handler: @escaping CheckoutProgressHandler) -> (String, UInt, UInt) -> Void {
    { path, completedSteps, totalSteps in
        handler(GitCheckoutProgress(path: path, completedSteps: completedSteps, totalSteps: totalSteps))
    }
}
