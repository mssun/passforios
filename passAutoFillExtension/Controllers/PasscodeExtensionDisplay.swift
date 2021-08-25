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
    func presentPasscodeLockIfNeeded(_ extensionVC: UIViewController) {
        extensionVC.view.isHidden = true
        guard PasscodeLock.shared.hasPasscode else {
            extensionVC.view.isHidden = false
            return
        }
        passcodeLockVC.modalPresentationStyle = .fullScreen
        extensionVC.parent?.present(passcodeLockVC, animated: false) {
            extensionVC.view.isHidden = false
        }
    }
}
