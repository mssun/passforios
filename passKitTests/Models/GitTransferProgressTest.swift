//
//  GitTransferProgressTest.swift
//  passKitTests
//
//  Created by Mingshen Sun on 8/8/26.
//  Copyright © 2026 Bob Sun. All rights reserved.
//

import XCTest
@testable import passKit

/// libgit2 reports receiving and indexing through the same callback, and a real
/// transfer runs through both too quickly to assert on, so the reading of those
/// counters is checked here rather than against a server.
final class GitTransferProgressTest: XCTestCase {
    private func progress(received: UInt32, indexed: UInt32, total: UInt32) -> GitTransferProgress {
        GitTransferProgress(receivedObjects: received, indexedObjects: indexed, totalObjects: total, receivedBytes: 0)
    }

    func testReceivingUntilEverythingHasArrived() {
        let halfway = progress(received: 50, indexed: 10, total: 100)
        XCTAssertEqual(halfway.phase, .receiving)
        XCTAssertEqual(halfway.receivedFraction, 0.5)
        XCTAssertEqual(halfway.fractionCompleted, 0.5)
    }

    func testIndexingOnceEverythingHasArrived() {
        let indexing = progress(received: 100, indexed: 25, total: 100)
        XCTAssertEqual(indexing.phase, .indexing)
        XCTAssertEqual(indexing.indexedFraction, 0.25)
        // The bar follows the phase, so it restarts from the indexed count.
        XCTAssertEqual(indexing.fractionCompleted, 0.25)
    }

    /// The first callbacks arrive before the server has said how much there is.
    func testUnknownTotalReadsAsReceivingNothing() {
        let starting = progress(received: 0, indexed: 0, total: 0)
        XCTAssertEqual(starting.phase, .receiving)
        XCTAssertEqual(starting.fractionCompleted, 0)
        XCTAssertEqual(starting.indexedFraction, 0)
    }

    func testFinished() {
        let done = progress(received: 100, indexed: 100, total: 100)
        XCTAssertEqual(done.phase, .indexing)
        XCTAssertEqual(done.fractionCompleted, 1)
    }

    /// A local clone has nothing to receive, so it is indexing from the start.
    func testEverythingLocal() {
        let local = progress(received: 4, indexed: 1, total: 4)
        XCTAssertEqual(local.phase, .indexing)
        XCTAssertEqual(local.fractionCompleted, 0.25)
    }

    func testStatusNamesThePhase() {
        let receiving = progress(received: 1, indexed: 0, total: 10).statusDescription("Syncing")
        let indexing = progress(received: 10, indexed: 1, total: 10).statusDescription("Syncing")

        XCTAssertTrue(receiving.hasPrefix("Syncing\n"), receiving)
        XCTAssertTrue(indexing.hasPrefix("Syncing\n"), indexing)
        XCTAssertNotEqual(receiving, indexing, "the phase has to be visible, not only the operation")
    }
}
