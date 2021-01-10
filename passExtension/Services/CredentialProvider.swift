//
//  CredentialProvider.swift
//  passExtension
//
//  Created by Sun, Mingshen on 1/9/21.
//  Copyright © 2021 Bob Sun. All rights reserved.
//

import UIKit
import MobileCoreServices
import passKit

class CredentialProvider {
    weak var extensionContext: NSExtensionContext?
    weak var viewController: UIViewController?

    init(viewController: UIViewController, extensionContext: NSExtensionContext) {
        self.viewController = viewController
        self.extensionContext = extensionContext
    }

    func provideCredentialsFindLogin(with passwordPath: String) {
        guard let viewController = viewController else {
            return
        }
        guard let extensionContext = extensionContext else {
            return
        }

        decryptPassword(in: viewController, with: passwordPath) { password in
            let extensionItem = NSExtensionItem()
            var returnDictionary = [
                PassExtensionKey.usernameKey: password.getUsernameForCompletion(),
                PassExtensionKey.passwordKey: password.password,
            ]
            if let totpPassword = password.currentOtp {
                returnDictionary[PassExtensionKey.totpKey] = totpPassword
            }
            extensionItem.attachments = [NSItemProvider(item: returnDictionary as NSSecureCoding, typeIdentifier: String(kUTTypePropertyList))]
            extensionContext.completeRequest(returningItems: [extensionItem])
        }
    }

    func provideCredentialsBrowser(with passwordPath: String) {
        guard let viewController = viewController else {
            return
        }
        guard let extensionContext = extensionContext else {
            return
        }

        decryptPassword(in: viewController, with: passwordPath) { password in
            Utils.copyToPasteboard(textToCopy: password.password)
            // return a dictionary for JavaScript for best-effor fill in
            let extensionItem = NSExtensionItem()
            let returnDictionary = [
                NSExtensionJavaScriptFinalizeArgumentKey: [
                    "username": password.getUsernameForCompletion(),
                    "password": password.password,
                ],
            ]
            extensionItem.attachments = [NSItemProvider(item: returnDictionary as NSSecureCoding, typeIdentifier: String(kUTTypePropertyList))]
            extensionContext.completeRequest(returningItems: [extensionItem])
        }
    }
}
