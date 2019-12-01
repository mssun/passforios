//
//  GitCredential.swift
//  pass
//
//  Created by Mingshen Sun on 30/4/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import ObjectiveGit
import SVProgressHUD

public func requestCredentialPassword(credential: GitCredential.Credential,
                                      lastPassword: String?,
                                      controller: UIViewController) -> String? {
    let sem = DispatchSemaphore(value: 0)
    var password: String?
    let message: String = {
        switch credential {
        case .http:
            return "FillInGitAccountPassword.".localize()
        case .ssh:
            return "FillInSshKeyPassphrase.".localize()
        }
    }()

    DispatchQueue.main.async {
        SVProgressHUD.dismiss()
        let alert = UIAlertController(title: "Password".localize(), message: message, preferredStyle: .alert)
        alert.addTextField() {
            $0.text = lastPassword ?? ""
            $0.isSecureTextEntry = true
        }
        alert.addAction(UIAlertAction(title: "Ok".localize(), style: .default) { _ in
            password = alert.textFields?.first?.text
            sem.signal()
        })
        alert.addAction(UIAlertAction(title: "Cancel".localize(), style: .cancel) { _ in
            password = nil
            sem.signal()
        })
        controller.present(alert, animated: true)
    }

    let _ = sem.wait(timeout: .distantFuture)
    return password
}

public struct GitCredential {
    private var credential: Credential
    private let passwordStore = PasswordStore.shared

    public enum Credential {
        case http(userName: String)
        case ssh(userName: String, privateKey: String)
    }

    public init(credential: Credential) {
        self.credential = credential
    }

    public func credentialProvider(requestCredentialPassword: @escaping (Credential, String?) -> String?) throws -> GTCredentialProvider {
        var attempts = 0
        return GTCredentialProvider { (_, _, _) -> (GTCredential?) in
            var credential: GTCredential? = nil

            switch self.credential {
            case let .http(userName):
                if attempts > 3 {
                    // After too many failures (say six), the error message "failed to authenticate ssh session" might be confusing.
                    return nil
                }
                var lastPassword = self.passwordStore.gitPassword
                if lastPassword == nil || attempts != 0 {
                    if let requestedPassword = requestCredentialPassword(self.credential, lastPassword) {
                        if SharedDefaults[.isRememberGitCredentialPassphraseOn] {
                            self.passwordStore.gitPassword = requestedPassword
                        }
                        lastPassword = requestedPassword
                    } else {
                        return nil
                    }
                }
                attempts += 1
                credential = try? GTCredential(userName: userName, password: lastPassword!)
            case let .ssh(userName, privateKey):
                if attempts > 0 {
                    // The passphrase seems correct, but the previous authentification failed.
                    return nil
                }
                var lastPassword = self.passwordStore.gitSSHPrivateKeyPassphrase
                if lastPassword == nil || attempts != 0  {
                    if let requestedPassword = requestCredentialPassword(self.credential, lastPassword) {
                        if SharedDefaults[.isRememberGitCredentialPassphraseOn] {
                            self.passwordStore.gitSSHPrivateKeyPassphrase = requestedPassword
                        }
                        lastPassword = requestedPassword
                    } else {
                        return nil
                    }
                }
                attempts += 1
                credential = try? GTCredential(userName: userName, publicKeyString: nil, privateKeyString: privateKey, passphrase: lastPassword!)
            }
            return credential
        }
    }

    public func delete() {
        switch credential {
        case .http:
            self.passwordStore.gitPassword = nil
        case .ssh:
            self.passwordStore.gitSSHPrivateKeyPassphrase = nil
        }
    }
}

