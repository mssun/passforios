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
    var originalExtensionContest: ASCredentialProviderExtensionContext?
    
    public convenience init(extensionContext: ASCredentialProviderExtensionContext?) {
        self.init()
        self.originalExtensionContest = extensionContext
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        cancelButton?.removeTarget(nil, action: nil, for: .allEvents)
        cancelButton?.addTarget(self, action: #selector(cancelExtension), for: .touchUpInside)
    }

    @objc
    func cancelExtension() {
        originalExtensionContest?.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userCanceled.rawValue))
    }
}

class PasscodeExtensionDisplay {
    private var isPasscodePresented = false
    private let passcodeLockVC: PasscodeLockViewControllerForExtension
    private let extensionContext: ASCredentialProviderExtensionContext?

    public init(extensionContext: ASCredentialProviderExtensionContext?) {
        self.extensionContext = extensionContext
        self.passcodeLockVC = PasscodeLockViewControllerForExtension(extensionContext: extensionContext)
        passcodeLockVC.dismissCompletionCallback = { [weak self] in
            self?.dismiss()
        }
        passcodeLockVC.setCancellable(true)
    }

    // present the passcode lock view if passcode is set and the view controller is not presented
    public func presentPasscodeLockIfNeeded(_ extensionVC: UIViewController) {
        guard PasscodeLock.shared.hasPasscode, !isPasscodePresented == true else {
            return
        }
        isPasscodePresented = true
        extensionVC.present(passcodeLockVC, animated: true, completion: nil)
    }

    public func dismiss(animated _: Bool = true) {
        isPasscodePresented = false
    }
}
