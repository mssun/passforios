//
//  PasscodeLockPresenter.swift
//  PasscodeLock
//
//  Created by Yishi Lin on 10/04/2018.
//  Copyright © 2018 Yishi Lin. All rights reserved.
//
//  Inspired by SwiftPasscodeLock created by Yanko Dimitrov.
//

import UIKit
import LocalAuthentication

open class PasscodeLockViewController: UIViewController, UITextFieldDelegate {

    open var dismissCompletionCallback: (()->Void)?
    open var successCallback: (()->Void)?
    open var cancelCallback: (()->Void)?

    weak var passcodeLabel: UILabel?
    weak var passcodeTextField: UITextField?
    weak var biometryAuthButton: UIButton?
    weak var forgotPasscodeButton: UIButton?
    open weak var cancelButton: UIButton?

    var isCancellable: Bool = false
    
    private let passwordStore = PasswordStore.shared

    open override func loadView() {
        super.loadView()

        let passcodeLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 300, height: 40))
        passcodeLabel.text = "EnterPasscode".localize()
        passcodeLabel.font = UIFont.boldSystemFont(ofSize: 18)
        passcodeLabel.textAlignment = .center
        passcodeLabel.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(passcodeLabel)
        self.passcodeLabel = passcodeLabel

        let passcodeTextField =  UITextField(frame: CGRect(x: 0, y: 0, width: 300, height: 40))
        passcodeTextField.borderStyle = UITextField.BorderStyle.roundedRect
        passcodeTextField.placeholder = "EnterPasscode".localize()
        passcodeTextField.isSecureTextEntry = true
        passcodeTextField.clearButtonMode = UITextField.ViewMode.whileEditing
        passcodeTextField.delegate = self
        passcodeTextField.addTarget(self, action: #selector(self.passcodeTextFieldDidChange(_:)), for: UIControl.Event.editingChanged)
        passcodeTextField.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(passcodeTextField)
        self.passcodeTextField = passcodeTextField

        if #available(iOSApplicationExtension 13.0, *) {
            view.backgroundColor = .systemBackground
            passcodeTextField.backgroundColor = .secondarySystemBackground
            passcodeTextField.textColor = .secondaryLabel
        } else {
            view.backgroundColor = .white
        }

        let biometryAuthButton = UIButton(type: .custom)
        biometryAuthButton.setTitle("", for: .normal)
        biometryAuthButton.setTitleColor(Globals.blue, for: .normal)
        biometryAuthButton.addTarget(self, action: #selector(bioButtonPressedAction(_:)), for: .touchUpInside)
        biometryAuthButton.isHidden = true
        biometryAuthButton.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(biometryAuthButton)
        self.biometryAuthButton = biometryAuthButton

        let myContext = LAContext()
        var authError: NSError?
        if #available(iOS 8.0, macOS 10.12.1, *) {
            if myContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) {
                var biometryType = "TouchId".localize()
                if #available(iOS 11.0, *) {
                    if myContext.biometryType == LABiometryType.faceID {
                        biometryType = "FaceId".localize()
                    }
                }
                biometryAuthButton.setTitle(biometryType, for: .normal)
                biometryAuthButton.isHidden = false
            }
        }
        
        let forgotPasscodeButton = UIButton(type: .custom)
        forgotPasscodeButton.setTitle("ForgotYourPasscode?".localize(), for: .normal)
        forgotPasscodeButton.setTitleColor(Globals.blue, for: .normal)
        forgotPasscodeButton.addTarget(self, action: #selector(forgotPasscodeButtonPressedAction(_:)), for: .touchUpInside)
        // hide the forgotPasscodeButton if the native app is running
        forgotPasscodeButton.isHidden = self.isCancellable
        forgotPasscodeButton.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(forgotPasscodeButton)
        self.forgotPasscodeButton = forgotPasscodeButton

        let cancelButton = UIButton(type: .custom)
        cancelButton.setTitle("Cancel".localize(), for: .normal)
        cancelButton.setTitleColor(Globals.blue, for: .normal)
        cancelButton.addTarget(self, action: #selector(passcodeLockDidCancel), for: .touchUpInside)
        cancelButton.isHidden = !self.isCancellable
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.contentHorizontalAlignment = UIControl.ContentHorizontalAlignment.left
        self.view.addSubview(cancelButton)
        self.cancelButton = cancelButton

        NSLayoutConstraint.activate([
            passcodeTextField.widthAnchor.constraint(equalToConstant: 300),
            passcodeTextField.heightAnchor.constraint(equalToConstant: 40),
            passcodeTextField.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            passcodeTextField.centerYAnchor.constraint(equalTo: self.view.centerYAnchor, constant: -20),
            // above passocde
            passcodeLabel.widthAnchor.constraint(equalToConstant: 300),
            passcodeLabel.heightAnchor.constraint(equalToConstant: 40),
            passcodeLabel.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            passcodeLabel.bottomAnchor.constraint(equalTo: passcodeTextField.topAnchor),
            // below passcode
            biometryAuthButton.widthAnchor.constraint(equalToConstant: 300),
            biometryAuthButton.heightAnchor.constraint(equalToConstant: 40),
            biometryAuthButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            biometryAuthButton.topAnchor.constraint(equalTo: passcodeTextField.bottomAnchor),
            // cancel (top-left of the screen)
            cancelButton.widthAnchor.constraint(equalToConstant: 150),
            cancelButton.heightAnchor.constraint(equalToConstant: 40),
            cancelButton.topAnchor.constraint(equalTo: self.view.safeTopAnchor),
            cancelButton.leftAnchor.constraint(equalTo: self.view.safeLeftAnchor, constant: 20),
            // bottom of the screen
            forgotPasscodeButton.widthAnchor.constraint(equalToConstant: 300),
            forgotPasscodeButton.heightAnchor.constraint(equalToConstant: 40),
            forgotPasscodeButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            forgotPasscodeButton.bottomAnchor.constraint(equalTo: self.view.safeBottomAnchor, constant: -40)
        ])

    }

    open override func viewDidLoad() {
        super.viewDidLoad()
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let biometryAuthButton = biometryAuthButton {
            self.bioButtonPressedAction(biometryAuthButton)
        }
    }

    internal func dismissPasscodeLock(completionHandler: (() -> Void)? = nil) {
        // clean up the textfield
        DispatchQueue.main.async {
            self.passcodeTextField?.text = ""
        }

        // pop
        if presentingViewController?.presentedViewController == self {
            // if presented as modal
            dismiss(animated: true, completion: { [weak self] in
                self?.dismissCompletionCallback?()
                completionHandler?()
            })
        } else {
            // if pushed in a navigation controller
            _ = navigationController?.popViewController(animated: true)
            dismissCompletionCallback?()
            completionHandler?()
        }
    }

    // MARK: - PasscodeLockDelegate

    open func passcodeLockDidSucceed() {
        dismissPasscodeLock(completionHandler: successCallback)
    }

    @objc func passcodeLockDidCancel() {
        dismissPasscodeLock(completionHandler: cancelCallback)
    }

    @objc func bioButtonPressedAction(_ uiButton: UIButton) {
        let myContext = LAContext()
        let myLocalizedReasonString = "AuthenticationNeeded.".localize()
        var authError: NSError?

        if #available(iOS 8.0, *) {
            if myContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) {
                myContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: myLocalizedReasonString) { success, evaluateError in
                    if success {
                        DispatchQueue.main.async {
                            // user authenticated successfully, take appropriate action
                            self.passcodeLockDidSucceed()
                        }
                    }
                }
            }
        }
    }

    @objc func forgotPasscodeButtonPressedAction(_ uiButton: UIButton) {
        let alert = UIAlertController(title: "ResetPass".localize(), message: "ResetPassExplanation.".localize(), preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "ErasePasswordStoreData".localize(), style: UIAlertAction.Style.destructive, handler: {[unowned self] (action) -> Void in
            let myContext = LAContext()
            var error: NSError?
            // If the device passcode is not set, reset the app.
            guard myContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
                self.passwordStore.erase()
                self.passcodeLockDidSucceed()
                return
            }
            // If the device passcode is set, authentication is required.
            myContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "ErasePasswordStoreData".localize()) { (success, error) in
                if success {
                    DispatchQueue.main.async {
                        // User authenticated successfully, take appropriate action
                        self.passwordStore.erase()
                        self.passcodeLockDidSucceed()
                    }
                } else {
                    DispatchQueue.main.async {
                        Utils.alert(title: "Error".localize(), message: error?.localizedDescription ?? "", controller: self, completion: nil)
                    }
                }
            }
        }))
        alert.addAction(UIAlertAction(title: "Dismiss".localize(), style: UIAlertAction.Style.cancel, handler:nil))
        self.present(alert, animated: true, completion: nil)
    }

    public override func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == passcodeTextField {
            if !PasscodeLock.shared.check(passcode: textField.text ?? "") {
                self.passcodeTextField?.placeholder =
                    "TryAgain".localize()
                self.passcodeTextField?.text = ""
            }
        }
        textField.resignFirstResponder()
        return true
    }

    @objc func passcodeTextFieldDidChange(_ textField: UITextField) {
        if PasscodeLock.shared.check(passcode: textField.text ?? "") {
            self.passcodeLockDidSucceed()
        }
    }

    public func setCancellable(_ isCancellable: Bool) {
        self.isCancellable = isCancellable
        cancelButton?.isHidden = !isCancellable
    }
}
