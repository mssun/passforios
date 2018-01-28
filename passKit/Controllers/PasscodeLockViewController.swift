//
//  PasscodeLockViewController.swift
//  PasscodeLock
//
//  Created by Yanko Dimitrov on 8/28/15.
//  Copyright © 2015 Yanko Dimitrov. All rights reserved.
//

import UIKit
import LocalAuthentication

open class PasscodeLockViewController: UIViewController {
    
    open var dismissCompletionCallback: (()->Void)?
    open var successCallback: (()->Void)?
    open var cancelCallback: (()->Void)?
    lazy var enterPasscodeAlert: UIAlertController = {
        let enterPasscodeAlert = UIAlertController(title: "Authenticate Pass", message: "Unlock with passcode for Pass", preferredStyle: .alert)

        enterPasscodeAlert.addTextField(configurationHandler: {(_ textField: UITextField) -> Void in
            textField.placeholder = "passcode"
            textField.isSecureTextEntry = true
            textField.addTarget(self, action: #selector(self.passcodeTextFieldDidChange(_:)), for: UIControlEvents.editingChanged)
            textField.clearButtonMode = UITextFieldViewMode.whileEditing
            textField.becomeFirstResponder()
        })
        
        let myContext = LAContext()
        var authError: NSError?
        if #available(iOS 8.0, macOS 10.12.1, *) {
            if myContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) {
                var biometryType = "Touch ID"
                if #available(iOS 11.0, *) {
                    if myContext.biometryType == LABiometryType.faceID {
                        biometryType = "Face ID"
                    }
                }
                let bioAction = UIAlertAction(title: "Use " + biometryType, style: .default) { (action:UIAlertAction) -> Void in
                    self.authenticate()
                }
                enterPasscodeAlert.addAction(bioAction)
            }
        }
        
        return enterPasscodeAlert
    }()
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.white
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        authenticate()
    }

    internal func dismissPasscodeLock(completionHandler: (() -> Void)? = nil) {
        // clean up the textfield
        enterPasscodeAlert.textFields?[0].text = ""
        if presentingViewController?.presentedViewController == self {
            // if presented as modal
            dismiss(animated: true, completion: { [weak self] in
                self?.dismissCompletionCallback?()
                completionHandler?()
            })
        // if pushed in a navigation controller
        } else {
            _ = navigationController?.popViewController(animated: true)
            dismissCompletionCallback?()
            completionHandler?()
        }
    }

    // MARK: - PasscodeLockDelegate

    open func passcodeLockDidSucceed() {
        dismissPasscodeLock(completionHandler: successCallback)
    }
    
    open func passcodeLockDidCancel() {
        dismissPasscodeLock(completionHandler: cancelCallback)
    }
    
    public func authenticate() {
        print(enterPasscodeAlert.isBeingPresented)
        
        let myContext = LAContext()
        let myLocalizedReasonString = "Authentication is needed to access Pass."
        var authError: NSError?
        
        if #available(iOS 8.0, *) {
            if myContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) {
                myContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: myLocalizedReasonString) { success, evaluateError in
                    if success {
                        DispatchQueue.main.async {
                            // user authenticated successfully, take appropriate action
                            self.passcodeLockDidSucceed()
                        }
                    } else {
                        // User did not authenticate successfully
                        self.showPasswordAlert()
                    }
                }
            } else {
                // could not evaluate policy; look at authError and present an appropriate message to user
                self.showPasswordAlert()
            }
        } else {
            // fallback on earlier versions
            self.showPasswordAlert()
        }
    }
    
    @objc func passcodeTextFieldDidChange(_ sender: UITextField) {
        // check whether the passcode is correct
        if PasscodeLock.shared.check(passcode: sender.text ?? "") {
            self.passcodeLockDidSucceed()
        }
    }
    
    func showPasswordAlert() {
        self.present(enterPasscodeAlert, animated: true, completion: nil)
    }
}
