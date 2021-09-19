//
//  CredentialProvider.swift
//  passExtension
//
//  Created by Sun, Mingshen on 1/9/21.
//  Copyright © 2021 Bob Sun. All rights reserved.
//

import MobileCoreServices
import passKit
import UIKit

class CredentialProvider {
    private let viewController: UIViewController
    private let extensionContext: NSExtensionContext
    private let afterDecryption: (Password) -> Void

    init(viewController: UIViewController, extensionContext: NSExtensionContext, afterDecryption: @escaping (Password) -> Void) {
        self.viewController = viewController
        self.extensionContext = extensionContext
        self.afterDecryption = afterDecryption
    }

    func provideCredentialsFindLogin(with passwordPath: String) {
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
            self.extensionContext.completeRequest(returningItems: [extensionItem])
            self.afterDecryption(password)
        }
    }

    func provideCredentialsBrowser(with passwordPath: String) {
        decryptPassword(in: viewController, with: passwordPath) { password in
            Utils.copyToPasteboard(textToCopy: password.password)
            // return a dictionary for JavaScript for best-effor fill in
            let extensionItem = NSExtensionItem()
            let returnDictionary = [
                NSExtensionJavaScriptFinalizeArgumentKey: [
                    PassExtensionKey.usernameKey: password.getUsernameForCompletion(),
                    PassExtensionKey.passwordKey: password.password,
                ],
            ]
            extensionItem.attachments = [NSItemProvider(item: returnDictionary as NSSecureCoding, typeIdentifier: String(kUTTypePropertyList))]
            self.extensionContext.completeRequest(returningItems: [extensionItem])
            self.afterDecryption(password)
        }
    }
}
