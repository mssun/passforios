//
//  PasscodeLockDisplay.swift
//  pass
//
//  Created by Yishi Lin on 14/6/17.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import PasscodeLock
import passKit

// add a cancel button in the passcode lock view
struct CancelableEnterPasscodeState: PasscodeLockStateType {
    let title: String = "Enter passcode"
    let description: String = "Enter passcode"
    let isCancellableAction = true
    var isTouchIDAllowed = true
    mutating func accept(passcode: String, from lock: PasscodeLockType) {
        if lock.repository.check(passcode: passcode) {
            lock.delegate?.passcodeLockDidSucceed(lock)
        }
    }
}

// cancel means cancel the extension
class PasscodeLockViewControllerForExtension: PasscodeLockViewController {
    var originalExtensionContest: NSExtensionContext?
    public convenience init(extensionContext: NSExtensionContext?, state: PasscodeLockStateType, configuration: PasscodeLockConfigurationType, animateOnDismiss: Bool = true) {
        self.init(state: state, configuration: configuration, animateOnDismiss: animateOnDismiss)
        originalExtensionContest = extensionContext
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        cancelButton?.removeTarget(nil, action: nil, for: .allEvents)
        cancelButton?.addTarget(self, action: #selector(cancelExtension), for: .touchUpInside)
    }
    @objc func cancelExtension() {
        originalExtensionContest?.completeRequest(returningItems: [], completionHandler: nil)
    }
}

class PasscodeExtensionDisplay {
    private var isPasscodePresented = false
    private let passcodeLockVC: PasscodeLockViewControllerForExtension
    
    init(extensionContext: NSExtensionContext?) {
        let cancelableEnter = CancelableEnterPasscodeState()
        passcodeLockVC = PasscodeLockViewControllerForExtension(extensionContext: extensionContext, state: cancelableEnter, configuration: PasscodeLockConfiguration.shared)
        passcodeLockVC.dismissCompletionCallback = { [weak self] in
            self?.dismiss()
        }
    }
    
    // present the passcode lock view if passcode is set and the view controller is not presented
    func presentPasscodeLockIfNeeded(_ extensionVC: ExtensionViewController) {
        guard PasscodeLockConfiguration.shared.repository.hasPasscode && !isPasscodePresented == true else {
            return
        }
        isPasscodePresented = true
        extensionVC.present(passcodeLockVC, animated: true, completion: nil)
    }
    
    func dismiss(animated: Bool = true) {
        isPasscodePresented = false
    }
}
