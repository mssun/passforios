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
        guard let pwCredentials = provideCredentials(in: viewController, with: recordIdentifier) else {
            return
        }

        extensionContext?.completeRequest(withSelectedCredential: pwCredentials)
    }

    func persistAndProvideCredentials(with passwordPath: String) {
        guard let pwCredentials = provideCredentials(in: viewController, with: passwordPath) else {
            return
        }
        guard let credentialIdentity = provideCredentialIdentity(for: identifier, user: pwCredentials.user, recordIdentifier: passwordPath) else {
            return
        }

        let store = ASCredentialIdentityStore.shared
        store.getState { state in
            if state.isEnabled {
                ASCredentialIdentityStore.shared.saveCredentialIdentities([credentialIdentity])
            }
        }
        extensionContext?.completeRequest(withSelectedCredential: pwCredentials)
    }
}

private func provideCredentialIdentity(for identifier: ASCredentialServiceIdentifier?, user: String, recordIdentifier: String?) -> ASPasswordCredentialIdentity? {
    guard let serviceIdentifier = identifier else {
        return nil
    }
    return ASPasswordCredentialIdentity(serviceIdentifier: serviceIdentifier, user: user, recordIdentifier: recordIdentifier)
}

private func provideCredentials(in viewController: UIViewController?, with path: String) -> ASPasswordCredential? {
    print(path)
    guard let viewController = viewController else {
        return nil
    }
    var credential: ASPasswordCredential?
    decryptPassword(in: viewController, with: path) { password in
        let username = password.getUsernameForCompletion()
        let password = password.password
        credential = ASPasswordCredential(user: username, password: password)
    }
    return credential
}
