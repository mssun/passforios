//
//  CredentialProviderViewController.swift
//  passAutoFillExtension
//
//  Created by Yishi Lin on 2018/9/24.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

import AuthenticationServices
import passKit

class CredentialProviderViewController: ASCredentialProviderViewController {
    var passcodelock: PasscodeExtensionDisplay {
        PasscodeExtensionDisplay(extensionContext: self.extensionContext)
    }

    var embeddedNavigationController: UINavigationController {
        children.first as! UINavigationController
    }

    var passwordsViewController: PasswordsViewController {
        embeddedNavigationController.viewControllers.first as! PasswordsViewController
    }

    lazy var credentialProvider = CredentialProvider(viewController: self, extensionContext: self.extensionContext)

    override func viewDidLoad() {
        super.viewDidLoad()
        passcodelock.presentPasscodeLockIfNeeded(self)

        let passwordsTableEntries = PasswordStore.shared.fetchPasswordEntityCoreData(withDir: false).compactMap { PasswordTableEntry($0) }
        let dataSource = PasswordsTableDataSource(entries: passwordsTableEntries)
        passwordsViewController.dataSource = dataSource
        passwordsViewController.selectionDelegate = self
    }

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        credentialProvider.identifier = serviceIdentifiers.first
        let url = serviceIdentifiers.first.flatMap { URL(string: $0.identifier) }
        passwordsViewController.navigationItem.prompt = url?.host
        let keywords = url?.host?.sanitizedDomain?.components(separatedBy: ".") ?? []
        passwordsViewController.showPasswordsWithSuggstion(keywords)
    }

    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        credentialProvider.credentials(for: credentialIdentity)
    }
}

extension CredentialProviderViewController: PasswordSelectionDelegate {
    func selected(password: PasswordTableEntry) {
        let passwordEntity = password.passwordEntity

        credentialProvider.persistAndProvideCredentials(with: passwordEntity.getPath())
    }
}

private extension String {
    var sanitizedDomain: String? {
        replacingOccurrences(of: ".com", with: "")
            .replacingOccurrences(of: ".org", with: "")
            .replacingOccurrences(of: ".edu", with: "")
            .replacingOccurrences(of: ".net", with: "")
            .replacingOccurrences(of: ".gov", with: "")
            .replacingOccurrences(of: "www.", with: "")
    }
}
