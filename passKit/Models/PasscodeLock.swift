//
//  PasscodeLock.swift
//  PassKit
//
//  Created by Yishi Lin on 28/1/2018.
//  Copyright © 2017 Yishi Lin. All rights reserved.
//

public class PasscodeLock {
    public static let shared = PasscodeLock()

    private static let identifier = Globals.bundleIdentifier + "passcode"

    /// Cached passcode to avoid frequent access to Keychain
    private var passcode: String? = AppKeychain.get(for: PasscodeLock.identifier)

    /// Constructor used to migrate passcode from SharedDefaults to Keychain
    private init() {
        if let passcode = SharedDefaults[.passcodeKey] {
            save(passcode: passcode)
            SharedDefaults[.passcodeKey] = nil
        }
    }

    public var hasPasscode: Bool {
        return passcode != nil
    }

    public func save(passcode: String) {
        AppKeychain.add(string: passcode, for: PasscodeLock.identifier)
        self.passcode = passcode
    }

    public func check(passcode: String) -> Bool {
        return self.passcode == passcode
    }

    public func delete() {
        AppKeychain.removeContent(for: PasscodeLock.identifier)
        passcode = nil
    }
}
