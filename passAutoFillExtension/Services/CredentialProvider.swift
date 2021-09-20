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
    private let viewController: UIViewController
    private let extensionContext: ASCredentialProviderExtensionContext
    private let afterDecryption: (Password) -> Void

    var identifier: ASCredentialServiceIdentifier?

    init(viewController: UIViewController, extensionContext: ASCredentialProviderExtensionContext, afterDecryption: @escaping (Password) -> Void) {
        self.viewController = viewController
        self.extensionContext = extensionContext
        self.afterDecryption = afterDecryption
    }

    func credentials(for identity: ASPasswordCredentialIdentity) {
        guard let recordIdentifier = identity.recordIdentifier else {
            return
        }

        decryptPassword(in: viewController, with: recordIdentifier) { password in
            self.extensionContext.completeRequest(withSelectedCredential: .from(password))
            self.afterDecryption(password)
        }
    }

    func persistAndProvideCredentials(with passwordPath: String) {
        decryptPassword(in: viewController, with: passwordPath) { password in
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
            self.extensionContext.completeRequest(withSelectedCredential: .from(password))
            self.afterDecryption(password)
        }
    }
}

extension ASPasswordCredential {
    static func from(_ password: Password) -> ASPasswordCredential {
        ASPasswordCredential(user: password.getUsernameForCompletion(), password: password.password)
    }
}
