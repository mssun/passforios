//
//  GitRepository.swift
//  pass
//
//  Created by Mingshen Sun on 1/25/25.
//  Copyright © 2025 Bob Sun. All rights reserved.
//

import Foundation
import Libgit2

// See Libgit2.swift for how the C API is reached. Everything crossing the
// public boundary of this class is a value type from GitTypes.swift.

public class GitRepository {
    private let repository: OpaquePointer
    var branchName: String = "master"

    deinit {
        git_repository_free(repository)
    }

    public init(with localDir: URL) throws {
        guard FileManager.default.fileExists(atPath: localDir.path) else {
            throw AppError.repositoryNotSet
        }
        initializeLibgit2()
        var repository: OpaquePointer?
        try gitTry(git_repository_open(&repository, localDir.path))
        guard let repository else {
            throw AppError.repositoryNotSet
        }
        self.repository = repository
        if let currentBranchName = try? Self.currentBranchName(in: repository) {
            self.branchName = currentBranchName
        }
    }

    public init(
        from remoteURL: URL,
        to workingDir: URL,
        branchName: String,
        options: GitCredentialOptions = GitCredentialOptions(),
        transferProgressBlock: @escaping TransferProgressHandler,
        checkoutProgressBlock: @escaping CheckoutProgressHandler
    ) throws {
        initializeLibgit2()
        let context = GitCallbackContext(
            credentialProvider: options.credentialProvider,
            transferProgress: transferProgressBlock
        )
        var cloneOptions = git_clone_options()
        try gitTry(git_clone_options_init(&cloneOptions, UInt32(GIT_CLONE_OPTIONS_VERSION)))
        cloneOptions.fetch_opts = try gitFetchOptions(context: context)
        cloneOptions.checkout_opts = try gitCheckoutOptions(strategy: GIT_CHECKOUT_SAFE)

        var repository: OpaquePointer?
        try withExtendedLifetime(context) {
            try gitTry(git_clone(&repository, remoteURL.absoluteString, workingDir.path, &cloneOptions))
        }
        guard let repository else {
            throw AppError.repositoryNotSet
        }
        self.repository = repository
        self.branchName = branchName

        guard git_repository_head_unborn(repository) != 1 else {
            return
        }
        if (try? Self.currentBranchName(in: repository)) != branchName {
            try checkoutAndChangeBranch(branchName: branchName, progressBlock: checkoutProgressBlock)
        }
    }

    private static func currentBranchName(in repository: OpaquePointer) throws -> String {
        var head: OpaquePointer?
        try gitTry(git_repository_head(&head, repository))
        defer { git_reference_free(head) }
        guard let name = gitString(git_reference_shorthand(head)) else {
            throw AppError.repositoryNotSet
        }
        return name
    }

    public func checkoutAndChangeBranch(branchName: String, progressBlock: @escaping CheckoutProgressHandler) throws {
        let context = GitCallbackContext(checkoutProgress: progressBlock)

        var localBranch: OpaquePointer?
        if git_branch_lookup(&localBranch, repository, branchName, GIT_BRANCH_LOCAL) != 0 {
            localBranch = nil
            try createLocalBranch(named: branchName, into: &localBranch)
        }
        guard let localBranch else {
            throw AppError.repositoryBranchNotFound(branchName: branchName)
        }
        defer { git_reference_free(localBranch) }

        try checkout(reference: localBranch, strategy: GIT_CHECKOUT_FORCE, context: context)
        try gitTry(git_repository_set_head(repository, git_reference_name(localBranch)))
        // Only once the branch is known to exist and to be checked out, so that
        // a failure does not leave the repository pointing at a missing branch.
        self.branchName = branchName
    }

    /// Branches off the matching remote branch and tracks it.
    private func createLocalBranch(named branchName: String, into localBranch: inout OpaquePointer?) throws {
        let remoteBranchName = "origin/\(branchName)"
        var remoteBranch: OpaquePointer?
        guard git_branch_lookup(&remoteBranch, repository, remoteBranchName, GIT_BRANCH_REMOTE) == 0,
              let remoteBranch,
              let remoteTarget = git_reference_target(remoteBranch) else {
            git_reference_free(remoteBranch)
            throw AppError.repositoryRemoteBranchNotFound(branchName: remoteBranchName)
        }
        defer { git_reference_free(remoteBranch) }

        var remoteCommit: OpaquePointer?
        try gitTry(git_commit_lookup(&remoteCommit, repository, remoteTarget))
        defer { git_commit_free(remoteCommit) }

        try gitTry(git_branch_create(&localBranch, repository, branchName, remoteCommit, 0))
        try gitTry(git_branch_set_upstream(localBranch, remoteBranchName))
    }

    private func checkout(reference: OpaquePointer, strategy: git_checkout_strategy_t, context: GitCallbackContext?) throws {
        var target: OpaquePointer?
        try gitTry(git_reference_peel(&target, reference, GIT_OBJECT_COMMIT))
        defer { git_object_free(target) }
        var options = try gitCheckoutOptions(strategy: strategy, context: context)
        try withExtendedLifetime(context) {
            try gitTry(git_checkout_tree(repository, target, &options))
        }
    }

    // MARK: - Remote operations

    public func pull(
        options: GitCredentialOptions,
        signature: GitSignature? = nil,
        transferProgressBlock: @escaping TransferProgressHandler
    ) throws {
        let context = GitCallbackContext(
            credentialProvider: options.credentialProvider,
            transferProgress: transferProgressBlock
        )
        var remote: OpaquePointer?
        try gitTry(git_remote_lookup(&remote, repository, "origin"))
        defer { git_remote_free(remote) }

        var fetchOptions = try gitFetchOptions(context: context)
        try withExtendedLifetime(context) {
            try gitTry(git_remote_fetch(remote, nil, &fetchOptions, nil))
        }

        try mergeUpstream(signature: signature)
    }

    /// libgit2 has no pull, so the fetched upstream is merged by hand: nothing to
    /// do when already up to date, a reference update when the merge is a
    /// fast-forward, and a real merge commit otherwise.
    private func mergeUpstream(signature: GitSignature?) throws {
        var head: OpaquePointer?
        try gitTry(git_repository_head(&head, repository))
        defer { git_reference_free(head) }

        var upstream: OpaquePointer?
        try gitTry(git_branch_upstream(&upstream, head))
        defer { git_reference_free(upstream) }

        var annotatedCommit: OpaquePointer?
        try gitTry(git_annotated_commit_from_ref(&annotatedCommit, repository, upstream))
        defer { git_annotated_commit_free(annotatedCommit) }

        var analysis = git_merge_analysis_t(0)
        var preference = git_merge_preference_t(0)
        var heads: [OpaquePointer?] = [annotatedCommit]
        try heads.withUnsafeMutableBufferPointer { buffer in
            try gitTry(git_merge_analysis(&analysis, &preference, repository, buffer.baseAddress, 1))
        }

        if analysis.rawValue & GIT_MERGE_ANALYSIS_UP_TO_DATE.rawValue != 0 {
            return
        }
        if analysis.rawValue & GIT_MERGE_ANALYSIS_FASTFORWARD.rawValue != 0 {
            try fastForward(head: head!, to: annotatedCommit!)
            return
        }
        try merge(heads: &heads, upstream: upstream!, signature: signature)
    }

    private func fastForward(head: OpaquePointer, to annotatedCommit: OpaquePointer) throws {
        guard let targetOid = git_annotated_commit_id(annotatedCommit) else {
            throw AppError.gitCommit
        }
        var target: OpaquePointer?
        try gitTry(git_object_lookup(&target, repository, targetOid, GIT_OBJECT_COMMIT))
        defer { git_object_free(target) }

        var options = try gitCheckoutOptions(strategy: GIT_CHECKOUT_SAFE)
        try gitTry(git_checkout_tree(repository, target, &options))

        var updatedHead: OpaquePointer?
        try gitTry(git_reference_set_target(&updatedHead, head, targetOid, "pull: Fast-forward"))
        git_reference_free(updatedHead)
    }

    private func merge(heads: inout [OpaquePointer?], upstream: OpaquePointer, signature: GitSignature?) throws {
        var mergeOptions = git_merge_options()
        try gitTry(git_merge_options_init(&mergeOptions, UInt32(GIT_MERGE_OPTIONS_VERSION)))
        var checkoutOptions = try gitCheckoutOptions(strategy: GIT_CHECKOUT_SAFE)
        try heads.withUnsafeMutableBufferPointer { buffer in
            try gitTry(git_merge(repository, buffer.baseAddress, 1, &mergeOptions, &checkoutOptions))
        }

        // A merge that is not carried through to a commit leaves conflicts in the
        // index and a half-merged work tree, which makes every later commit fail
        // in git_index_write_tree. Undo it unless the commit is created.
        var committed = false
        defer {
            if !committed {
                abortMerge()
            }
            git_repository_state_cleanup(repository)
        }

        var index: OpaquePointer?
        try gitTry(git_repository_index(&index, repository))
        defer { git_index_free(index) }

        if git_index_has_conflicts(index) != 0 {
            throw GitMergeConflictError(paths: conflictedPaths(in: index))
        }

        var upstreamCommit: OpaquePointer?
        try gitTry(git_reference_peel(&upstreamCommit, upstream, GIT_OBJECT_COMMIT))
        defer { git_commit_free(upstreamCommit) }

        let mergeSignature = try signature ?? defaultSignature()
        _ = try createCommit(
            message: "Merge branch '\(branchName)' of origin",
            signature: mergeSignature,
            additionalParents: [upstreamCommit]
        )
        committed = true
    }

    /// Returns the index and the work tree to HEAD, discarding a merge that was
    /// started but not committed.
    private func abortMerge() {
        var head: OpaquePointer?
        guard git_repository_head(&head, repository) == 0 else {
            return
        }
        defer { git_reference_free(head) }

        var headCommit: OpaquePointer?
        guard git_reference_peel(&headCommit, head, GIT_OBJECT_COMMIT) == 0 else {
            return
        }
        defer { git_commit_free(headCommit) }

        guard var options = try? gitCheckoutOptions(strategy: GIT_CHECKOUT_FORCE) else {
            return
        }
        git_reset(repository, headCommit, GIT_RESET_HARD, &options)
    }

    private func conflictedPaths(in index: OpaquePointer?) -> [String] {
        var iterator: OpaquePointer?
        guard git_index_conflict_iterator_new(&iterator, index) == 0 else {
            return []
        }
        defer { git_index_conflict_iterator_free(iterator) }

        var paths: [String] = []
        while true {
            var ancestor: UnsafePointer<git_index_entry>?
            var our: UnsafePointer<git_index_entry>?
            var their: UnsafePointer<git_index_entry>?
            guard git_index_conflict_next(&ancestor, &our, &their, iterator) == 0 else {
                break
            }
            let entry = our ?? their ?? ancestor
            if let path = gitString(entry?.pointee.path) {
                paths.append(path)
            }
        }
        return paths
    }

    public func push(
        options: GitCredentialOptions,
        transferProgressBlock: @escaping PushProgressHandler
    ) throws {
        let context = GitCallbackContext(
            credentialProvider: options.credentialProvider,
            pushProgress: transferProgressBlock
        )
        var remote: OpaquePointer?
        try gitTry(git_remote_lookup(&remote, repository, "origin"))
        defer { git_remote_free(remote) }

        var pushOptions = try gitPushOptions(context: context)
        let currentBranch = try Self.currentBranchName(in: repository)
        let refspec = "refs/heads/\(currentBranch):refs/heads/\(currentBranch)"

        try withExtendedLifetime(context) {
            try refspec.withCString { refspec in
                var refspecs: [UnsafeMutablePointer<CChar>?] = [UnsafeMutablePointer(mutating: refspec)]
                try refspecs.withUnsafeMutableBufferPointer { buffer in
                    var array = git_strarray(strings: buffer.baseAddress, count: 1)
                    try gitTry(git_remote_push(remote, &array, &pushOptions))
                }
            }
        }

        guard context.rejectedReferences.isEmpty else {
            throw AppError.gitPushNotSuccessful
        }
    }

    // MARK: - Working tree

    private var workingDirectory: URL? {
        gitString(git_repository_workdir(repository)).map { URL(fileURLWithPath: $0) }
    }

    public func add(path: String) throws {
        var index: OpaquePointer?
        try gitTry(git_repository_index(&index, repository))
        defer { git_index_free(index) }
        try gitTry(git_index_add_bypath(index, path))
        try gitTry(git_index_write(index))
    }

    public func rm(path: String) throws {
        guard let workingDirectory else {
            throw AppError.repositoryNotSet
        }
        let url = workingDirectory.appendingPathComponent(path)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        var index: OpaquePointer?
        try gitTry(git_repository_index(&index, repository))
        defer { git_index_free(index) }
        try gitTry(git_index_remove_bypath(index, path))
        try gitTry(git_index_write(index))
    }

    public func mv(from: String, to: String) throws {
        guard let workingDirectory else {
            throw AppError.repositoryNotSet
        }
        try FileManager.default.moveItem(
            at: workingDirectory.appendingPathComponent(from),
            to: workingDirectory.appendingPathComponent(to)
        )
        try add(path: to)
        try rm(path: from)
    }

    // MARK: - Commits

    public func commit(name: String, email: String, message: String) throws -> GitCommit {
        try commit(signature: GitSignature(name: name, email: email), message: message)
    }

    public func commit(signature: GitSignature, message: String) throws -> GitCommit {
        try createCommit(message: message, signature: signature, additionalParents: [])
    }

    private func createCommit(message: String, signature: GitSignature, additionalParents: [OpaquePointer?]) throws -> GitCommit {
        var index: OpaquePointer?
        try gitTry(git_repository_index(&index, repository))
        defer { git_index_free(index) }

        var treeOid = git_oid()
        try gitTry(git_index_write_tree(&treeOid, index))
        var tree: OpaquePointer?
        try gitTry(git_tree_lookup(&tree, repository, &treeOid))
        defer { git_tree_free(tree) }

        var head: OpaquePointer?
        var headCommit: OpaquePointer?
        defer {
            git_reference_free(head)
            git_commit_free(headCommit)
        }

        var referenceName = "HEAD"
        var parents: [OpaquePointer?] = []
        if git_repository_head_unborn(repository) != 1 {
            try gitTry(git_repository_head(&head, repository))
            referenceName = gitString(git_reference_name(head)) ?? "HEAD"
            try gitTry(git_reference_peel(&headCommit, head, GIT_OBJECT_COMMIT))
            parents.append(headCommit)
        }
        parents.append(contentsOf: additionalParents)

        var commitOid = git_oid()
        try signature.withBackendSignature { signature in
            try parents.withUnsafeMutableBufferPointer { parents in
                try gitTry(git_commit_create(
                    &commitOid,
                    repository,
                    referenceName,
                    signature,
                    signature,
                    nil,
                    message,
                    tree,
                    parents.count,
                    parents.baseAddress
                ))
            }
        }

        var commit: OpaquePointer?
        try gitTry(git_commit_lookup(&commit, repository, &commitOid))
        defer { git_commit_free(commit) }
        guard let commit else {
            throw AppError.gitCommit
        }
        return GitCommit(commit)
    }

    private func defaultSignature() throws -> GitSignature {
        var signature: UnsafeMutablePointer<git_signature>?
        try gitTry(git_signature_default(&signature, repository))
        defer { git_signature_free(signature) }
        guard let signature = GitSignature(signature) else {
            throw AppError.gitCreateSignature
        }
        return signature
    }

    public func getRecentCommits(count: Int) throws -> [GitCommit] {
        try commits(of: try walkOids(limit: count))
    }

    public func getLocalCommits() throws -> [GitCommit] {
        try commits(of: try localCommitOids())
    }

    public func numberOfCommits() -> Int {
        ((try? walkOids(limit: nil)) ?? []).count
    }

    /// Walks back from HEAD, optionally stopping after `limit` commits.
    private func walkOids(limit: Int?) throws -> [git_oid] {
        var walker: OpaquePointer?
        try gitTry(git_revwalk_new(&walker, repository))
        defer { git_revwalk_free(walker) }
        try gitTry(git_revwalk_push_head(walker))

        var oids: [git_oid] = []
        var oid = git_oid()
        while limit.map({ oids.count < $0 }) ?? true, git_revwalk_next(&oid, walker) == 0 {
            oids.append(oid)
        }
        return oids
    }

    /// Commits reachable from HEAD but not from the tracked remote branch, newest first.
    private func localCommitOids() throws -> [git_oid] {
        let remoteBranchName = "origin/\(branchName)"
        var remoteBranch: OpaquePointer?
        guard git_branch_lookup(&remoteBranch, repository, remoteBranchName, GIT_BRANCH_REMOTE) == 0,
              let remoteBranch else {
            git_reference_free(remoteBranch)
            throw AppError.repositoryRemoteBranchNotFound(branchName: remoteBranchName)
        }
        defer { git_reference_free(remoteBranch) }

        var walker: OpaquePointer?
        try gitTry(git_revwalk_new(&walker, repository))
        defer { git_revwalk_free(walker) }
        try gitTry(git_revwalk_push_head(walker))
        if let remoteTarget = git_reference_target(remoteBranch) {
            try gitTry(git_revwalk_hide(walker, remoteTarget))
        }

        var oids: [git_oid] = []
        var oid = git_oid()
        while git_revwalk_next(&oid, walker) == 0 {
            oids.append(oid)
        }
        return oids
    }

    private func commits(of oids: [git_oid]) throws -> [GitCommit] {
        try oids.map { oid in
            var oid = oid
            var commit: OpaquePointer?
            try gitTry(git_commit_lookup(&commit, repository, &oid))
            defer { git_commit_free(commit) }
            guard let commit else {
                throw AppError.gitCommit
            }
            return GitCommit(commit)
        }
    }

    public func reset() throws {
        let localCommits = try localCommitOids()
        guard var oldestLocalCommitOid = localCommits.last else {
            return
        }
        var oldestLocalCommit: OpaquePointer?
        try gitTry(git_commit_lookup(&oldestLocalCommit, repository, &oldestLocalCommitOid))
        defer { git_commit_free(oldestLocalCommit) }

        guard git_commit_parentcount(oldestLocalCommit) == 1 else {
            throw AppError.gitReset
        }
        var newHead: OpaquePointer?
        try gitTry(git_commit_parent(&newHead, oldestLocalCommit, 0))
        defer { git_commit_free(newHead) }

        var options = try gitCheckoutOptions(strategy: GIT_CHECKOUT_FORCE)
        try gitTry(git_reset(repository, newHead, GIT_RESET_HARD, &options))
    }

    public func lastCommitDate(path: String) throws -> Date {
        var options = git_blame_options()
        try gitTry(git_blame_options_init(&options, UInt32(GIT_BLAME_OPTIONS_VERSION)))

        var blame: OpaquePointer?
        try gitTry(git_blame_file(&blame, repository, path, &options))
        defer { git_blame_free(blame) }

        var latest: TimeInterval = 0
        for index in 0 ..< git_blame_get_hunk_count(blame) {
            guard let hunk = git_blame_get_hunk_byindex(blame, index),
                  let signature = hunk.pointee.final_signature else {
                continue
            }
            latest = max(latest, TimeInterval(signature.pointee.when.time))
        }
        return Date(timeIntervalSince1970: latest)
    }
}
