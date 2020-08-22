//
//  SyncRepositoryIntentHandler.swift
//  passShortcuts
//
//  Created by Danny Moesch on 03.03.20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import Intents
import passKit

public class SyncRepositoryIntentHandler: NSObject, SyncRepositoryIntentHandling {
    private let passwordStore = PasswordStore.shared
    private let keychain = AppKeychain.shared

    private var gitCredential: GitCredential {
        GitCredential.from(
            authenticationMethod: Defaults.gitAuthenticationMethod,
            userName: Defaults.gitUsername,
            keyStore: keychain
        )
    }

    public func handle(intent _: SyncRepositoryIntent, completion: @escaping (SyncRepositoryIntentResponse) -> Void) {
        guard passwordStore.repositoryExists() else {
            completion(SyncRepositoryIntentResponse(code: .noRepository, userActivity: nil))
            return
        }
        guard isPasswordRemembered else {
            completion(SyncRepositoryIntentResponse(code: .noPassphrase, userActivity: nil))
            return
        }
        do {
            try passwordStore.pullRepository(options: gitCredential.getCredentialOptions())
        } catch {
            completion(SyncRepositoryIntentResponse(code: .pullFailed, userActivity: nil))
            return
        }
        if passwordStore.numberOfLocalCommits > 0 {
            do {
                try passwordStore.pushRepository(options: gitCredential.getCredentialOptions())
            } catch {
                completion(SyncRepositoryIntentResponse(code: .pushFailed, userActivity: nil))
                return
            }
        }
        completion(SyncRepositoryIntentResponse(code: .success, userActivity: nil))
    }

    private var isPasswordRemembered: Bool {
        let authenticationMethod = Defaults.gitAuthenticationMethod
        return authenticationMethod == .password && keychain.contains(key: Globals.gitPassword)
            || authenticationMethod == .key && keychain.contains(key: Globals.gitSSHPrivateKeyPassphrase)
    }
}
