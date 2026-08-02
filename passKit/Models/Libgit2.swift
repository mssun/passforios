//
//  Libgit2.swift
//  passKit
//
//  Created by Mingshen Sun on 8/2/26.
//  Copyright © 2026 Bob Sun. All rights reserved.
//

import Foundation

// libgit2 is built by scripts/libgit2_build.sh into an xcframework holding it,
// libssh2 and the OpenSSL libcrypto libssh2 needs.
import Libgit2

// MARK: - Library lifecycle

private let libgit2IsInitialized: Bool = {
    git_libgit2_init()
    return true
}()

/// Initializes libgit2 once per process. Every entry point into the library
/// has to call this first.
func initializeLibgit2() {
    _ = libgit2IsInitialized
}

// MARK: - Errors

/// An error reported by libgit2. The message is the one libgit2 produced, which
/// for network and authentication failures is the message of the underlying
/// library, for instance libssh2.
public struct Libgit2Error: LocalizedError {
    public let code: Int32
    public let klass: Int32
    public let message: String

    public var errorDescription: String? { message }

    static func last(code: Int32) -> Self {
        guard let error = git_error_last(), let message = gitString(error.pointee.message) else {
            return Self(code: code, klass: 0, message: "Git error \(code)")
        }
        return Self(code: code, klass: error.pointee.klass, message: message)
    }
}

/// A merge that could not be completed automatically.
public struct GitMergeConflictError: LocalizedError {
    public let paths: [String]

    public var errorDescription: String? {
        "MergeConflictError".localize(paths.joined(separator: ", "))
    }
}

public extension Error {
    /// Whether the stored git credential could plausibly be at fault. Failures
    /// that can only happen once the remote has already accepted it must not
    /// cause it to be thrown away.
    var mightBeAuthenticationFailure: Bool {
        switch self {
        case is GitMergeConflictError:
            return false
        case let error as AppError where error == .gitPushNotSuccessful:
            return false
        default:
            return true
        }
    }
}

/// Turns a libgit2 return code into a Swift error. Negative codes are failures,
/// everything else is passed through, since some functions report counts.
@discardableResult
func gitTry(_ result: Int32) throws -> Int32 {
    guard result >= 0 else {
        throw Libgit2Error.last(code: result)
    }
    return result
}

// MARK: - Value conversion

func gitString(_ pointer: UnsafePointer<CChar>?) -> String? {
    pointer.map { String(cString: $0) }
}

func gitString(_ oid: UnsafePointer<git_oid>?) -> String {
    guard let oid else {
        return ""
    }
    var buffer = [CChar](repeating: 0, count: 41)
    git_oid_tostr(&buffer, buffer.count, oid)
    return String(cString: buffer)
}

extension GitTransferProgress {
    init(_ progress: git_indexer_progress) {
        self.init(
            receivedObjects: progress.received_objects,
            indexedObjects: progress.indexed_objects,
            totalObjects: progress.total_objects,
            receivedBytes: progress.received_bytes
        )
    }
}

extension GitSignature {
    init?(_ signature: UnsafePointer<git_signature>?) {
        guard let signature,
              let name = gitString(signature.pointee.name),
              let email = gitString(signature.pointee.email) else {
            return nil
        }
        self.init(name: name, email: email, time: Date(timeIntervalSince1970: TimeInterval(signature.pointee.when.time)))
    }

    /// Creates the libgit2 signature and hands it to `body`, freeing it afterwards.
    /// Throws if libgit2 rejects the name or email.
    func withBackendSignature<T>(_ body: (UnsafeMutablePointer<git_signature>) throws -> T) throws -> T {
        var signature: UnsafeMutablePointer<git_signature>?
        let offset = Int32(TimeZone.current.secondsFromGMT(for: time) / 60)
        try gitTry(git_signature_new(&signature, name, email, git_time_t(time.timeIntervalSince1970), offset))
        guard let signature else {
            throw AppError.gitCreateSignature
        }
        defer { git_signature_free(signature) }
        return try body(signature)
    }

    /// Whether libgit2 accepts this name and email.
    public var isValid: Bool {
        initializeLibgit2()
        return (try? withBackendSignature { _ in }) != nil
    }
}

extension GitCommit {
    init(_ commit: OpaquePointer) {
        self.init(
            sha: gitString(git_commit_id(commit)),
            message: gitString(git_commit_message(commit)),
            date: Date(timeIntervalSince1970: TimeInterval(git_commit_time(commit))),
            author: GitSignature(git_commit_author(commit))
        )
    }
}

// MARK: - Callbacks

/// Carries the Swift handlers of one operation through the `void *payload` of
/// the libgit2 callbacks. Kept alive by the function running the operation.
final class GitCallbackContext {
    let credentialProvider: GitCredentialProvider?
    let transferProgress: TransferProgressHandler?
    let checkoutProgress: CheckoutProgressHandler?
    let pushProgress: PushProgressHandler?

    /// References the remote refused during a push, keyed by reference name.
    private(set) var rejectedReferences: [String: String] = [:]

    init(
        credentialProvider: GitCredentialProvider? = nil,
        transferProgress: TransferProgressHandler? = nil,
        checkoutProgress: CheckoutProgressHandler? = nil,
        pushProgress: PushProgressHandler? = nil
    ) {
        self.credentialProvider = credentialProvider
        self.transferProgress = transferProgress
        self.checkoutProgress = checkoutProgress
        self.pushProgress = pushProgress
    }

    var payload: UnsafeMutableRawPointer {
        Unmanaged.passUnretained(self).toOpaque()
    }

    fileprivate func reject(reference: String, reason: String) {
        rejectedReferences[reference] = reason
    }

    fileprivate static func from(_ payload: UnsafeMutableRawPointer?) -> GitCallbackContext? {
        payload.map { Unmanaged<GitCallbackContext>.fromOpaque($0).takeUnretainedValue() }
    }
}

let gitTransferProgressCallback: git_indexer_progress_cb = { stats, payload in
    guard let stats, let handler = GitCallbackContext.from(payload)?.transferProgress else {
        return 0
    }
    var stop = false
    handler(GitTransferProgress(stats.pointee), &stop)
    return stop ? -1 : 0
}

let gitCheckoutProgressCallback: git_checkout_progress_cb = { path, completedSteps, totalSteps, payload in
    guard let handler = GitCallbackContext.from(payload)?.checkoutProgress else {
        return
    }
    handler(GitCheckoutProgress(path: gitString(path), completedSteps: UInt(completedSteps), totalSteps: UInt(totalSteps)))
}

let gitPushProgressCallback: git_push_transfer_progress_cb = { current, total, bytes, payload in
    guard let handler = GitCallbackContext.from(payload)?.pushProgress else {
        return 0
    }
    var stop = false
    handler(GitPushProgress(current: current, total: total, bytes: bytes), &stop)
    return stop ? -1 : 0
}

/// Records rejections instead of failing, so that all of them can be reported together.
let gitPushUpdateReferenceCallback: git_push_update_reference_cb = { refname, status, payload in
    guard let context = GitCallbackContext.from(payload), let refname, let status else {
        return 0
    }
    context.reject(reference: String(cString: refname), reason: String(cString: status))
    return 0
}

/// libgit2 reports the message left in its error slot, which without this would
/// be whatever an earlier operation put there, or nothing at all.
private func failCredentials(_ message: String) -> Int32 {
    git_error_set_str(Int32(GIT_ERROR_NET.rawValue), message)
    return -1
}

let gitCredentialsCallback: git_credential_acquire_cb = { credential, _, _, allowedTypes, payload in
    guard let credential, let provider = GitCallbackContext.from(payload)?.credentialProvider else {
        return failCredentials("AuthenticationRequired.".localize())
    }
    // Asked before the credential itself when the remote URL carries no user name.
    if allowedTypes & GIT_CREDENTIAL_USERNAME.rawValue != 0 {
        return git_credential_username_new(credential, provider.userName)
    }
    switch provider.nextCredential() {
    case let .userPassPlaintext(userName, password):
        return git_credential_userpass_plaintext_new(credential, userName, password)
    case let .sshKeyMemory(userName, publicKey, privateKey, passphrase):
        return git_credential_ssh_key_memory_new(credential, userName, publicKey, privateKey, passphrase)
    case .none:
        return failCredentials("AuthenticationCancelled.".localize())
    }
}

// MARK: - Option builders

func gitCheckoutOptions(strategy: git_checkout_strategy_t, context: GitCallbackContext? = nil) throws -> git_checkout_options {
    var options = git_checkout_options()
    try gitTry(git_checkout_options_init(&options, UInt32(GIT_CHECKOUT_OPTIONS_VERSION)))
    options.checkout_strategy = strategy.rawValue
    if let context, context.checkoutProgress != nil {
        options.progress_cb = gitCheckoutProgressCallback
        options.progress_payload = context.payload
    }
    return options
}

func gitFetchOptions(context: GitCallbackContext) throws -> git_fetch_options {
    var options = git_fetch_options()
    try gitTry(git_fetch_options_init(&options, UInt32(GIT_FETCH_OPTIONS_VERSION)))
    options.callbacks.transfer_progress = gitTransferProgressCallback
    options.callbacks.credentials = gitCredentialsCallback
    options.callbacks.payload = context.payload
    return options
}

func gitPushOptions(context: GitCallbackContext) throws -> git_push_options {
    var options = git_push_options()
    try gitTry(git_push_options_init(&options, UInt32(GIT_PUSH_OPTIONS_VERSION)))
    options.callbacks.push_transfer_progress = gitPushProgressCallback
    options.callbacks.push_update_reference = gitPushUpdateReferenceCallback
    options.callbacks.credentials = gitCredentialsCallback
    options.callbacks.payload = context.payload
    return options
}
