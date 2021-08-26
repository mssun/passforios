//
//  PasscodeLockDisplay.swift
//  pass
//
//  Created by Yishi Lin on 14/6/17.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import AuthenticationServices
import Foundation
import passKit

// cancel means cancel the extension
class PasscodeLockViewControllerForExtension: PasscodeLockViewController {
    var originalExtensionContext: NSExtensionContext!

    convenience init(extensionContext: NSExtensionContext) {
        self.init()
        self.originalExtensionContext = extensionContext
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        cancelButton?.removeTarget(nil, action: nil, for: .allEvents)
        cancelButton?.addTarget(self, action: #selector(cancelExtension), for: .touchUpInside)
    }

    @objc
    func cancelExtension() {
        originalExtensionContext.cancelRequest(withError: NSError(domain: "PassExtension", code: 0))
    }
}

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
