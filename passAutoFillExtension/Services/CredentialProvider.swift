//
//  CredentialProvider.swift
//  passAutoFillExtension
//
//  Created by Sun, Mingshen on 1/2/21.
//  Copyright © 2021 Bob Sun. All rights reserved.
//

import AuthenticationServices
import passKit

class CredentialProvider {
    var identifier: ASCredentialServiceIdentifier?
    weak var extensionContext: ASCredentialProviderExtensionContext?
    weak var viewController: UIViewController?

    init(viewController: UIViewController, extensionContext: ASCredentialProviderExtensionContext) {
        self.viewController = viewController
        self.extensionContext = extensionContext
    }

    func credentials(for identity: ASPasswordCredentialIdentity) {
        guard let recordIdentifier = identity.recordIdentifier else {
            return
        }

        provideCredentials(in: viewController, with: recordIdentifier) { credential in
            guard let credential = credential else {
                return
            }
            self.extensionContext?.completeRequest(withSelectedCredential: credential)
        }
    }

    func persistAndProvideCredentials(with passwordPath: String) {
        provideCredentials(in: viewController, with: passwordPath) { credential in
            guard let credential = credential else {
                return
            }
            guard let credentialIdentity = provideCredentialIdentity(for: self.identifier, user: credential.user, recordIdentifier: passwordPath) else {
                return
            }

            let store = ASCredentialIdentityStore.shared
            store.getState { state in
                if state.isEnabled {
                    ASCredentialIdentityStore.shared.saveCredentialIdentities([credentialIdentity])
                }
            }
            self.extensionContext?.completeRequest(withSelectedCredential: credential)
        }
    }
}

private func provideCredentialIdentity(for identifier: ASCredentialServiceIdentifier?, user: String, recordIdentifier: String?) -> ASPasswordCredentialIdentity? {
    guard let serviceIdentifier = identifier else {
        return nil
    }
    return ASPasswordCredentialIdentity(serviceIdentifier: serviceIdentifier, user: user, recordIdentifier: recordIdentifier)
}

private func provideCredentials(in viewController: UIViewController?, with path: String, completion: @escaping ((ASPasswordCredential?) -> Void)) {
    guard let viewController = viewController else {
        return
    }
    decryptPassword(in: viewController, with: path) { password in
        let username = password.getUsernameForCompletion()
        let password = password.password
        let credential = ASPasswordCredential(user: username, password: password)
        completion(credential)
    }
}
