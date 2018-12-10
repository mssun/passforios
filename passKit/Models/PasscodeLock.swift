//
//  PasscodeLock.swift
//  PassKit
//
//  Created by Yishi Lin on 28/1/2018.
//  Copyright © 2017 Yishi Lin. All rights reserved.
//

import Foundation
import LocalAuthentication

open class PasscodeLock {
    public static let shared = PasscodeLock()

    fileprivate let passcodeKey = "passcode.lock.passcode"
    fileprivate var passcode: String? {
        return SharedDefaults[.passcodeKey]
    }

    public var hasPasscode: Bool {
        return passcode != nil
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
