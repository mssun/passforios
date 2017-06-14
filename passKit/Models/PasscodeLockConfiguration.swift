//
//  PasscodeLockConfiguration.swift
//  pass
//
//  Created by Mingshen Sun on 7/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import PasscodeLock

public struct PasscodeLockConfiguration: PasscodeLockConfigurationType {
    
    public static let shared = PasscodeLockConfiguration()
    
    public let repository: PasscodeRepositoryType
    public let passcodeLength = 4
    public var isTouchIDAllowed = SharedDefaults[.isTouchIDOn]
    public let shouldRequestTouchIDImmediately = true
    public let maximumInccorectPasscodeAttempts = 3
    
    init() {
        self.repository = PasscodeLockRepository()
    }
}
