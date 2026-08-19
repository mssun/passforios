//
//  GitTypes.swift
//  passKit
//
//  Created by Mingshen Sun on 8/2/26.
//  Copyright © 2026 Bob Sun. All rights reserved.
//

import Foundation

// Backend-agnostic value types forming the public surface of `GitRepository`.
//
// Nothing here may refer to a git backend (ObjectiveGit, libgit2, ...). Keeping
// this file free of such imports is what allows the backend to be replaced by
// rewriting `GitRepository.swift` and `GitCredential.swift` alone.

/// Author or committer of a commit.
public struct GitSignature: Equatable {
    public let name: String
    public let email: String
    public let time: Date

    public init(name: String, email: String, time: Date = Date()) {
        self.name = name
        self.email = email
        self.time = time
    }
}

/// A single commit, detached from the repository it was read from.
public struct GitCommit: Equatable {
    public let sha: String
    public let message: String?
    public let date: Date
    public let author: GitSignature?

    public init(sha: String, message: String?, date: Date, author: GitSignature?) {
        self.sha = sha
        self.message = message
        self.date = date
        self.author = author
    }
}

/// Progress of a fetch or clone, reported while objects are received.
public struct GitTransferProgress: Equatable {
    public let receivedObjects: UInt32
    public let indexedObjects: UInt32
    public let totalObjects: UInt32
    public let receivedBytes: Int

    public init(receivedObjects: UInt32, indexedObjects: UInt32, totalObjects: UInt32, receivedBytes: Int) {
        self.receivedObjects = receivedObjects
        self.indexedObjects = indexedObjects
        self.totalObjects = totalObjects
        self.receivedBytes = receivedBytes
    }

    /// What the transfer is doing now. libgit2 reports both counters in every
    /// callback: objects are received first and indexed afterwards, so which
    /// one is worth showing depends on how far along it is.
    public enum Phase: Equatable {
        case receiving
        case indexing
    }

    /// Indexing only begins once everything has arrived. Before the total is
    /// known there is nothing to index, so that counts as receiving too.
    public var phase: Phase {
        totalObjects > 0 && receivedObjects >= totalObjects ? .indexing : .receiving
    }

    /// Fraction of objects received, or `0` while the total is still unknown.
    public var receivedFraction: Float {
        fraction(of: receivedObjects)
    }

    /// Fraction of objects indexed, which trails the received one.
    public var indexedFraction: Float {
        fraction(of: indexedObjects)
    }

    /// The fraction of whichever phase is running, for a single progress bar.
    public var fractionCompleted: Float {
        switch phase {
        case .receiving:
            return receivedFraction
        case .indexing:
            return indexedFraction
        }
    }

    /// What to put above a progress bar: the operation, and under it the phase
    /// the fraction belongs to, so that a bar which restarts from zero when
    /// indexing begins is not mistaken for one that lost its place.
    public func statusDescription(_ operation: String) -> String {
        switch phase {
        case .receiving:
            return "\(operation)\n\("ReceivingObjects".localize())"
        case .indexing:
            return "\(operation)\n\("IndexingObjects".localize())"
        }
    }

    private func fraction(of objects: UInt32) -> Float {
        totalObjects > 0 ? Float(objects) / Float(totalObjects) : 0
    }
}

/// Progress of a push, reported while objects are sent.
public struct GitPushProgress: Equatable {
    public let current: UInt32
    public let total: UInt32
    public let bytes: Int

    public init(current: UInt32, total: UInt32, bytes: Int) {
        self.current = current
        self.total = total
        self.bytes = bytes
    }

    /// Fraction of objects pushed, or `0` while the total is still unknown.
    public var fractionCompleted: Float {
        total > 0 ? Float(current) / Float(total) : 0
    }
}

/// Progress of a checkout, reported per checked out path.
public struct GitCheckoutProgress: Equatable {
    public let path: String?
    public let completedSteps: UInt
    public let totalSteps: UInt

    public init(path: String?, completedSteps: UInt, totalSteps: UInt) {
        self.path = path
        self.completedSteps = completedSteps
        self.totalSteps = totalSteps
    }

    /// Fraction of steps completed, or `0` while the total is still unknown.
    public var fractionCompleted: Float {
        totalSteps > 0 ? Float(completedSteps) / Float(totalSteps) : 0
    }
}

/// Set `stop` to `true` to abort the running operation.
public typealias TransferProgressHandler = (GitTransferProgress, inout Bool) -> Void
public typealias PushProgressHandler = (GitPushProgress, inout Bool) -> Void
public typealias CheckoutProgressHandler = (GitCheckoutProgress) -> Void
