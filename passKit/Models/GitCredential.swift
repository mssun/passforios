//
//  GitCredential.swift
//  passKit
//
//  Created by Mingshen Sun on 30/4/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import ObjectiveGit
import SVProgressHUD

public struct GitCredential {
    public typealias PasswordProvider = (String, String?) -> String?

    private let credentialType: CredentialType
    private let keyStore: KeyStore

    private enum CredentialType {
        case http(userName: String)
        case ssh(userName: String, privateKey: String)

        var requestPassphraseMessage: String {
            switch self {
            case .http:
                return "FillInGitAccountPassword.".localize()
            case .ssh:
                return "FillInSshKeyPassphrase.".localize()
            }
        }

        var keyStoreKey: String {
            switch self {
            case .http:
                return Globals.gitPassword
            case .ssh:
                return Globals.gitSSHPrivateKeyPassphrase
            }
        }

        var allowedAttempts: Int {
            switch self {
            case .http:
                return 4
            case .ssh:
                return 1
            }
        }

        func createGTCredential(password: String) throws -> GTCredential {
            switch self {
            case let .http(userName):
                return try GTCredential(userName: userName, password: password)
            case let .ssh(userName, privateKey):
                return try GTCredential(userName: userName, publicKeyString: nil, privateKeyString: privateKey, passphrase: password)
            }
        }
    }

    public static func from(authenticationMethod: GitAuthenticationMethod, userName: String, keyStore: KeyStore) -> Self {
        switch authenticationMethod {
        case .password:
            return Self(credentialType: .http(userName: userName), keyStore: keyStore)
        case .key:
            let privateKey: String = keyStore.get(for: SSHKey.PRIVATE.getKeychainKey()) ?? ""
            return Self(credentialType: .ssh(userName: userName, privateKey: privateKey), keyStore: keyStore)
        }
    }

    public func getCredentialOptions(passwordProvider: @escaping PasswordProvider = { _, _ in nil }) -> [String: Any] {
        let credentialProvider = createCredentialProvider(passwordProvider)
        return [
            GTRepositoryCloneOptionsCredentialProvider: credentialProvider,
            GTRepositoryRemoteOptionsCredentialProvider: credentialProvider,
        ]
    }

    private func createCredentialProvider(_ passwordProvider: @escaping PasswordProvider) -> GTCredentialProvider {
        var attempts = 1
        return GTCredentialProvider { _, _, _ -> GTCredential? in
            if attempts > self.credentialType.allowedAttempts {
                return nil
            }
            guard let password = self.getPassword(attempts: attempts, passwordProvider: passwordProvider) else {
                return nil
            }
            attempts += 1
            return try? self.credentialType.createGTCredential(password: password)
        }
    }

    public func delete() {
        keyStore.removeContent(for: credentialType.keyStoreKey)
    }

    private func getPassword(attempts: Int, passwordProvider: @escaping PasswordProvider) -> String? {
        let lastPassword: String? = keyStore.get(for: credentialType.keyStoreKey)
        if lastPassword == nil || attempts != 1 {
            guard let requestedPassword = passwordProvider(credentialType.requestPassphraseMessage, lastPassword) else {
                return nil
            }
            if Defaults.isRememberGitCredentialPassphraseOn {
                keyStore.add(string: requestedPassword, for: credentialType.keyStoreKey)
            }
            return requestedPassword
        }
        return lastPassword
    }
}
