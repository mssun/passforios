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

    weak var passcodeTextField: UITextField?
    weak var biometryAuthButton: UIButton?
    weak var forgotPasscodeButton: UIButton?
    open weak var cancelButton: UIButton?

    var isCancellable: Bool = false
    
    private let passwordStore = PasswordStore.shared

    open override func loadView() {
        super.loadView()

        let passcodeTextField =  UITextField()
        passcodeTextField.borderStyle = UITextField.BorderStyle.roundedRect
        passcodeTextField.placeholder = "EnterPasscode".localize()
        passcodeTextField.isSecureTextEntry = true
        passcodeTextField.clearButtonMode = UITextField.ViewMode.whileEditing
        passcodeTextField.delegate = self
        passcodeTextField.addTarget(self, action: #selector(self.passcodeTextFieldDidChange(_:)), for: UIControl.Event.editingChanged)
        passcodeTextField.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(passcodeTextField)
        self.passcodeTextField = passcodeTextField

        view.backgroundColor = Colors.systemBackground
        passcodeTextField.backgroundColor = Colors.secondarySystemBackground
        passcodeTextField.textColor = Colors.secondaryLabel

        let biometryAuthButton = UIButton(type: .custom)
        biometryAuthButton.setTitle("", for: .normal)
        biometryAuthButton.setTitleColor(Colors.systemBlue, for: .normal)
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
                biometryAuthButton.titleLabel?.font = UIFont.systemFont(ofSize: UIFont.systemFontSize)
                biometryAuthButton.isHidden = false
            }
        }
        
        let forgotPasscodeButton = UIButton(type: .custom)
        forgotPasscodeButton.setTitle("ForgotYourPasscode?".localize(), for: .normal)
        forgotPasscodeButton.titleLabel?.font = UIFont.systemFont(ofSize: UIFont.systemFontSize)
        forgotPasscodeButton.setTitleColor(Colors.systemBlue, for: .normal)
        forgotPasscodeButton.addTarget(self, action: #selector(forgotPasscodeButtonPressedAction(_:)), for: .touchUpInside)
        // hide the forgotPasscodeButton if the native app is running
        forgotPasscodeButton.isHidden = self.isCancellable
        forgotPasscodeButton.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(forgotPasscodeButton)
        self.forgotPasscodeButton = forgotPasscodeButton

        let cancelButton = UIButton(type: .custom)
        cancelButton.setTitle("Cancel".localize(), for: .normal)
        cancelButton.setTitleColor(Colors.systemBlue, for: .normal)
        cancelButton.addTarget(self, action: #selector(passcodeLockDidCancel), for: .touchUpInside)
        cancelButton.isHidden = !self.isCancellable
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.contentHorizontalAlignment = UIControl.ContentHorizontalAlignment.left
        self.view.addSubview(cancelButton)
        self.cancelButton = cancelButton
        
        // Display the Pass icon in the middle of the screen
        let bundle = Bundle(for: PasscodeLockViewController.self)
        let appIcon = UIImage(named: "PasscodeLockViewIcon", in: bundle, compatibleWith: nil)
        let appIconSize = (appIcon?.size.height) ?? 0
        let appIconView = UIImageView(image: appIcon)
        appIconView.translatesAutoresizingMaskIntoConstraints = false
        appIconView.layer.cornerRadius = appIconSize / 5
        appIconView.layer.masksToBounds = true
        self.view?.addSubview(appIconView)

        NSLayoutConstraint.activate([
            passcodeTextField.widthAnchor.constraint(equalToConstant: 250),
            passcodeTextField.heightAnchor.constraint(equalToConstant: 40),
            passcodeTextField.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            passcodeTextField.centerYAnchor.constraint(equalTo: self.view.centerYAnchor, constant: -20),
            // above passocde
            appIconView.widthAnchor.constraint(equalToConstant: appIconSize),
            appIconView.heightAnchor.constraint(equalToConstant: appIconSize),
            appIconView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            appIconView.bottomAnchor.constraint(equalTo: passcodeTextField.topAnchor, constant: -appIconSize),
            // below passcode
            biometryAuthButton.widthAnchor.constraint(equalToConstant: 250),
            biometryAuthButton.heightAnchor.constraint(equalToConstant: 40),
            biometryAuthButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            biometryAuthButton.topAnchor.constraint(equalTo: passcodeTextField.bottomAnchor),
            // cancel (top-left of the screen)
            cancelButton.widthAnchor.constraint(equalToConstant: 150),
            cancelButton.heightAnchor.constraint(equalToConstant: 40),
            cancelButton.topAnchor.constraint(equalTo: self.view.safeTopAnchor),
            cancelButton.leftAnchor.constraint(equalTo: self.view.safeLeftAnchor, constant: 20),
            // bottom of the screen
            forgotPasscodeButton.widthAnchor.constraint(equalToConstant: 250),
            forgotPasscodeButton.heightAnchor.constraint(equalToConstant: 40),
            forgotPasscodeButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            forgotPasscodeButton.bottomAnchor.constraint(equalTo: self.view.safeBottomAnchor, constant: -40)
        ])

        // dismiss keyboard when tapping anywhere
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing))
        view.addGestureRecognizer(tap)

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
                self.passcodeTextField?.shake()
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
