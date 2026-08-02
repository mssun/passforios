//
//  GitCredential.swift
//  passKit
//
//  Created by Mingshen Sun on 30/4/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation

/// What to authenticate with, described independently of the git backend.
public enum GitCredentialSpec {
    case userPassPlaintext(userName: String, password: String)
    case sshKeyMemory(userName: String, publicKey: String?, privateKey: String, passphrase: String)
}

/// Answers the credential requests of a single remote operation. libgit2 asks
/// repeatedly until it is authenticated or the provider gives up, which is what
/// makes retrying with a re-entered password possible.
public final class GitCredentialProvider {
    public let userName: String
    private let provideCredential: () -> GitCredentialSpec?

    init(userName: String, provideCredential: @escaping () -> GitCredentialSpec?) {
        self.userName = userName
        self.provideCredential = provideCredential
    }

    /// The credential for the next attempt, or `nil` to stop trying.
    public func nextCredential() -> GitCredentialSpec? {
        provideCredential()
    }
}

/// Credentials handed to a remote operation.
public struct GitCredentialOptions {
    let credentialProvider: GitCredentialProvider?

    /// Options without any credentials, for remotes that do not require authentication.
    public init() {
        self.credentialProvider = nil
    }

    init(credentialProvider: GitCredentialProvider) {
        self.credentialProvider = credentialProvider
    }
}

public struct GitCredential {
    public typealias PasswordProvider = (String, String?) -> String?

    private let credentialType: CredentialType
    private let keyStore: KeyStore

    private enum CredentialType {
        case http(userName: String)
        case ssh(userName: String, privateKey: String)

        var userName: String {
            switch self {
            case let .http(userName), let .ssh(userName, _):
                return userName
            }
        }

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

        func createCredential(password: String) -> GitCredentialSpec {
            switch self {
            case let .http(userName):
                return .userPassPlaintext(userName: userName, password: password)
            case let .ssh(userName, privateKey):
                return .sshKeyMemory(userName: userName, publicKey: nil, privateKey: privateKey, passphrase: password)
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

    public func getCredentialOptions(passwordProvider: @escaping PasswordProvider = { _, _ in nil }) -> GitCredentialOptions {
        GitCredentialOptions(credentialProvider: createCredentialProvider(passwordProvider))
    }

    func createCredentialProvider(_ passwordProvider: @escaping PasswordProvider) -> GitCredentialProvider {
        var attempts = 1
        return GitCredentialProvider(userName: credentialType.userName) {
            if attempts > credentialType.allowedAttempts {
                return nil
            }
            guard let password = getPassword(attempts: attempts, passwordProvider: passwordProvider) else {
                return nil
            }
            attempts += 1
            return credentialType.createCredential(password: password)
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
