//
//  PasscodeRepository.swift
//  pass
//
//  Created by Mingshen Sun on 7/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import PasscodeLock
import passKit

public class PasscodeLockRepository: PasscodeRepositoryType {
    private let passcodeKey = "passcode.lock.passcode"
    
    public var hasPasscode: Bool {
        
        if passcode != nil {
            return true
        }
        
        return false
    }
    
    private var passcode: String? {
        return SharedDefaults[.passcodeKey]
    }
    
    public func save(passcode: String) {
        SharedDefaults[.passcodeKey] = passcode
    }
    
    public func check(passcode: String) -> Bool {
        return self.passcode == passcode
    }
    
    public func delete() {
        SharedDefaults[.passcodeKey] = nil
    }
}
