//
//  PasscodeExtensionDisplay.swift
//  passAutoFillExtension
//
//  Created by Yishi Lin on 14/6/17.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import passKit

class PasscodeExtensionDisplay {
    private let passcodeLockVC: PasscodeLockViewControllerForExtension
    private let extensionContext: NSExtensionContext?

    init(extensionContext: NSExtensionContext) {
        self.extensionContext = extensionContext
        self.passcodeLockVC = PasscodeLockViewControllerForExtension(extensionContext: extensionContext)
        passcodeLockVC.setCancellable(true)
    }

    // present the passcode lock view if passcode is set and the view controller is not presented
    func presentPasscodeLockIfNeeded(_ sender: UIViewController, before: (() -> Void)? = nil, after: (() -> Void)? = nil) {
        if PasscodeLock.shared.hasPasscode {
            before?()
            passcodeLockVC.successCallback = after
            passcodeLockVC.modalPresentationStyle = .fullScreen
            sender.parent?.present(passcodeLockVC, animated: false) {
                after?()
            }
        } else {
            after?()
        }
    }
}
