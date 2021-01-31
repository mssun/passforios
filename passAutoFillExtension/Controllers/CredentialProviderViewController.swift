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
        PasscodeExtensionDisplay(extensionContext: extensionContext)
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
        passwordsViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
    }

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        credentialProvider.identifier = serviceIdentifiers.first
        let url = serviceIdentifiers.first.flatMap { URL(string: $0.identifier) }
        passwordsViewController.navigationItem.prompt = url?.host
        passwordsViewController.showPasswordsWithSuggstion(matching: url?.host ?? "")
    }

    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        credentialProvider.identifier = credentialIdentity.serviceIdentifier
        if !PasscodeLock.shared.hasPasscode, Defaults.isRememberPGPPassphraseOn {
            credentialProvider.credentials(for: credentialIdentity)
        } else {
            extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userInteractionRequired.rawValue))
        }
    }

    override func prepareInterfaceToProvideCredential(for credentialIdentity: ASPasswordCredentialIdentity) {
        guard let identifier = credentialIdentity.recordIdentifier else {
            return
        }
        credentialProvider.identifier = credentialIdentity.serviceIdentifier
        passwordsViewController.navigationItem.prompt = identifier
        passwordsViewController.showPasswordsWithSuggstion(matching: identifier)
    }

    @objc
    private func cancel(_: AnyObject?) {
        extensionContext.cancelRequest(withError: NSError(domain: "PassExtension", code: 0))
    }
}

extension CredentialProviderViewController: PasswordSelectionDelegate {
    func selected(password: PasswordTableEntry) {
        let passwordEntity = password.passwordEntity

        credentialProvider.persistAndProvideCredentials(with: passwordEntity.getPath())
    }
}
