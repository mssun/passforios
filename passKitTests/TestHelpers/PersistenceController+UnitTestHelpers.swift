//
//  PersistenceController+UnitTestHelpers.swift
//  pass
//
//  Created by Lysann Tranvouez on 2026-03-12.
//  Copyright © 2026 Bob Sun. All rights reserved.
//

@testable import passKit

extension PersistenceController {
    static func forUnitTests() -> PersistenceController {
        PersistenceController(storeURL: URL(fileURLWithPath: "/dev/null"))
    }
}
