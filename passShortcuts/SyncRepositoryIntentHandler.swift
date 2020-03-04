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
        switch Defaults.gitAuthenticationMethod {
        case .password:
            return GitCredential(credential: .http(userName: Defaults.gitUsername))
        case .key:
            let privateKey: String = keychain.get(for: SshKey.PRIVATE.getKeychainKey()) ?? ""
            return GitCredential(credential: .ssh(userName: Defaults.gitUsername, privateKey: privateKey))
        }
    }

    public func handle(intent: SyncRepositoryIntent, completion: @escaping (SyncRepositoryIntentResponse) -> Void) {
        guard passwordStore.repositoryExists() else {
            completion(SyncRepositoryIntentResponse(code: .noRepository, userActivity: nil))
            return
        }
        guard isPasswordRemembered else {
            completion(SyncRepositoryIntentResponse(code: .noPassphrase, userActivity: nil))
            return
        }
        do {
            try passwordStore.pullRepository(credential: gitCredential, requestCredentialPassword: { _, _ in nil }, progressBlock: { _, _ in })
        } catch {
            completion(SyncRepositoryIntentResponse(code: .pullFailed, userActivity: nil))
            return
        }
        if passwordStore.numberOfLocalCommits > 0 {
            do {
                try passwordStore.pushRepository(credential: gitCredential, requestCredentialPassword: { _, _ in nil }, transferProgressBlock: { _, _, _, _ in })
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
