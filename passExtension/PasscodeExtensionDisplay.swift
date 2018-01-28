//
//  PasscodeLockDisplay.swift
//  pass
//
//  Created by Yishi Lin on 14/6/17.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import passKit

class PasscodeExtensionDisplay {
    private var isPasscodePresented = false
    private let passcodeLockVC: PasscodeLockViewController
    
    init(extensionContext: NSExtensionContext?) {
        passcodeLockVC = PasscodeLockViewController()
        passcodeLockVC.dismissCompletionCallback = { [weak self] in
            self?.dismiss()
        }
    }
    
    // present the passcode lock view if passcode is set and the view controller is not presented
    func presentPasscodeLockIfNeeded(_ extensionVC: ExtensionViewController) {
        guard PasscodeLock.shared.hasPasscode && !isPasscodePresented == true else {
            return
        }
        isPasscodePresented = true
        extensionVC.present(passcodeLockVC, animated: true, completion: nil)
    }
    
    func dismiss(animated: Bool = true) {
        isPasscodePresented = false
    }
}
