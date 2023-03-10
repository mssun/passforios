//
//  ExtensionViewController.swift
//  passExtension
//
//  Created by Yishi Lin on 13/6/17.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import MobileCoreServices
import passKit

class ExtensionViewController: UIViewController {
    private lazy var passcodelock: PasscodeExtensionDisplay = { [unowned self] in
        PasscodeExtensionDisplay(extensionContext: extensionContext!)
    }()

    private lazy var passwordsViewController: PasswordsViewController = (children.first as! UINavigationController).viewControllers.first as! PasswordsViewController

    private lazy var credentialProvider: CredentialProvider = { [unowned self] in
        CredentialProvider(viewController: self, extensionContext: extensionContext!, afterDecryption: NotificationCenterDispatcher.showOTPNotification)
    }()

    private lazy var passwordsTableEntries = PasswordStore.shared.fetchPasswordEntityCoreData(withDir: false)
        .map(PasswordTableEntry.init)

    enum Action {
        case findLogin, fillBrowser, unknown
    }

    private var action = Action.unknown

    override func viewDidLoad() {
        super.viewDidLoad()
        view.isHidden = true
        passwordsViewController.dataSource = PasswordsTableDataSource(entries: passwordsTableEntries)
        passwordsViewController.selectionDelegate = self
        passwordsViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancel)
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        prepareCredentialList()
        passcodelock.presentPasscodeLockIfNeeded(self, after: { [unowned self] in
            view.isHidden = false
        })
    }

    @objc
    private func cancel(_: AnyObject?) {
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func prepareCredentialList() {
        guard let attachments = extensionContext?.attachments else {
            return
        }

        func completeTask(_ text: String?) {
            DispatchQueue.main.async {
                self.passwordsViewController.showPasswordsWithSuggestion(matching: text ?? "")
                self.passwordsViewController.navigationItem.prompt = text
            }
        }
        DispatchQueue.global(qos: .userInitiated).async {
            for attachment in attachments {
                if attachment.hasURL {
                    self.action = .fillBrowser
                    attachment.extractSearchText { completeTask($0) }
                } else if attachment.hasFindLoginAction {
                    self.action = .findLogin
                    attachment.extractSearchText { completeTask($0) }
                } else if attachment.hasPropertyList {
                    self.action = .fillBrowser
                    attachment.extractSearchText { completeTask($0) }
                } else {
                    self.action = .unknown
                }
            }
        }
    }
}

extension ExtensionViewController: PasswordSelectionDelegate {
    func selected(password: PasswordTableEntry) {
        switch action {
        case .findLogin:
            credentialProvider.provideCredentialsFindLogin(with: password.passwordEntity.getPath())
        case .fillBrowser:
            credentialProvider.provideCredentialsBrowser(with: password.passwordEntity.getPath())
        default:
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
}

extension NSDictionary {
    func extractSearchText() -> String? {
        if let value = self[PassExtensionKey.URLStringKey] as? String {
            if let host = URL(string: value)?.host {
                return host
            }
            return value
        } else if let value = self[NSExtensionJavaScriptPreprocessingResultsKey] as? String {
            if let host = URL(string: value)?.host {
                return host
            }
            return value
        }
        return nil
    }
}

extension NSItemProvider {
    var hasFindLoginAction: Bool {
        hasItemConformingToTypeIdentifier(PassExtensionActions.findLogin)
    }

    var hasURL: Bool {
        hasItemConformingToTypeIdentifier(kUTTypeURL as String) && registeredTypeIdentifiers.count == 1
    }

    var hasPropertyList: Bool {
        hasItemConformingToTypeIdentifier(kUTTypePropertyList as String)
    }
}

extension NSExtensionContext {
    /// Get all the attachments to this post.
    var attachments: [NSItemProvider] {
        guard let items = inputItems as? [NSExtensionItem] else {
            return []
        }
        return items.flatMap { $0.attachments ?? [] }
    }
}

extension NSItemProvider {
    /// Extracts the URL from the item provider
    func extractSearchText(completion: @escaping (String?) -> Void) {
        loadItem(forTypeIdentifier: kUTTypeURL as String) { item, _ in
            if let url = item as? NSURL {
                completion(url.host)
            } else {
                completion(nil)
            }
        }

        loadItem(forTypeIdentifier: kUTTypePropertyList as String) { item, _ in
            if let dict = item as? NSDictionary {
                if let result = dict[NSExtensionJavaScriptPreprocessingResultsKey] as? NSDictionary {
                    completion(result.extractSearchText())
                }
            }
        }

        loadItem(forTypeIdentifier: PassExtensionActions.findLogin) { item, _ in
            if let dict = item as? NSDictionary {
                let text = dict.extractSearchText()
                completion(text)
            }
        }
    }
}
