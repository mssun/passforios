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

    private let afterDecryption: (Password) -> Void

    init(viewController: UIViewController, extensionContext: ASCredentialProviderExtensionContext, afterDecryption: @escaping (Password) -> Void) {
        self.viewController = viewController
        self.extensionContext = extensionContext
        self.afterDecryption = afterDecryption
    }

    func credentials(for identity: ASPasswordCredentialIdentity) {
        guard let recordIdentifier = identity.recordIdentifier else {
            return
        }

        provideCredentials(in: viewController, with: recordIdentifier) { password in
            self.extensionContext?.completeRequest(withSelectedCredential: .from(password))
            self.afterDecryption(password)
        }
    }

    func persistAndProvideCredentials(with passwordPath: String) {
        provideCredentials(in: viewController, with: passwordPath) { password in
            if let identifier = self.identifier {
                ASCredentialIdentityStore.shared.getState { state in
                    guard state.isEnabled else {
                        return
                    }
                    let credentialIdentity = ASPasswordCredentialIdentity(
                        serviceIdentifier: identifier,
                        user: password.getUsernameForCompletion(),
                        recordIdentifier: passwordPath
                    )
                    ASCredentialIdentityStore.shared.saveCredentialIdentities([credentialIdentity])
                }
            }
            self.extensionContext?.completeRequest(withSelectedCredential: .from(password))
            self.afterDecryption(password)
        }
    }

    private func provideCredentials(in viewController: UIViewController?, with path: String, completion: @escaping (Password) -> Void) {
        guard let viewController = viewController else {
            return
        }
        decryptPassword(in: viewController, with: path, completion: completion)
    }
}

extension ASPasswordCredential {
    static func from(_ password: Password) -> ASPasswordCredential {
        ASPasswordCredential(user: password.getUsernameForCompletion(), password: password.password)
    }
}
