//
//  PasscodeLock.swift
//  passKit
//
//  Created by Yishi Lin on 28/1/2018.
//  Copyright © 2017 Yishi Lin. All rights reserved.
//

public class PasscodeLock {
    public static let shared = PasscodeLock()

    private let identifier = Globals.bundleIdentifier + "passcode"

    private var passcode: String? {
        AppKeychain.shared.get(for: identifier)
    }

    /// Constructor used to migrate passcode from SharedDefaults to Keychain
    private init() {
        if let passcode = Defaults.passcodeKey {
            save(passcode: passcode)
            Defaults.passcodeKey = nil
        }
    }

    public var hasPasscode: Bool {
        passcode != nil
    }

    public func save(passcode: String) {
        AppKeychain.shared.add(string: passcode, for: identifier)
    }

    public func check(passcode: String) -> Bool {
        self.passcode == passcode
    }

    public func delete() {
        AppKeychain.shared.removeContent(for: identifier)
    }
}
