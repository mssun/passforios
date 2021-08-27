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
    private lazy var passcodelock: PasscodeExtensionDisplay = { [unowned self] in
        PasscodeExtensionDisplay(extensionContext: extensionContext)
    }()

    private lazy var passwordsViewController: PasswordsViewController = {
        (children.first as! UINavigationController).viewControllers.first as! PasswordsViewController
    }()

    private lazy var credentialProvider: CredentialProvider = { [unowned self] in
        CredentialProvider(viewController: self, extensionContext: extensionContext)
    }()

    private lazy var passwordsTableEntries = PasswordStore.shared.fetchPasswordEntityCoreData(withDir: false)
        .map(PasswordTableEntry.init(_:))

    override func viewDidLoad() {
        super.viewDidLoad()
        passwordsViewController.dataSource = PasswordsTableDataSource(entries: passwordsTableEntries)
        passwordsViewController.selectionDelegate = self
        passwordsViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancel)
        )
    }

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        passcodelock.presentPasscodeLockIfNeeded(self) {
            self.view.isHidden = true
        } after: { [unowned self] in
            self.view.isHidden = false
            self.credentialProvider.identifier = serviceIdentifiers.first
            let url = serviceIdentifiers.first
                .map(\.identifier)
                .flatMap(URL.init(string:))
            self.passwordsViewController.navigationItem.prompt = url?.host
            self.passwordsViewController.showPasswordsWithSuggestion(matching: url?.host ?? "")
        }
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
        passcodelock.presentPasscodeLockIfNeeded(self) {
            self.view.isHidden = true
        } after: { [unowned self] in
            self.credentialProvider.credentials(for: credentialIdentity)
        }
    }

    @objc
    private func cancel(_: AnyObject?) {
        extensionContext.cancelRequest(withError: NSError(domain: "PassExtension", code: 0))
    }
}

extension CredentialProviderViewController: PasswordSelectionDelegate {
    func selected(password: PasswordTableEntry) {
        credentialProvider.persistAndProvideCredentials(with: password.passwordEntity.getPath())
    }
}
