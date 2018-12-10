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
    weak var passcodeWrongAttemptsLabel: UILabel?
    weak var passcodeTextField: UITextField?
    weak var biometryAuthButton: UIButton?
    open weak var cancelButton: UIButton?

    var passcodeFailedAttempts = 0
    var isCancellable: Bool = false

    open override func loadView() {
        super.loadView()

        let passcodeLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 300, height: 40))
        passcodeLabel.text = "Enter passcode for Pass"
        passcodeLabel.font = UIFont.boldSystemFont(ofSize: 18)
        passcodeLabel.textColor = UIColor.black
        passcodeLabel.textAlignment = .center
        passcodeLabel.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(passcodeLabel)
        self.passcodeLabel = passcodeLabel

        let passcodeWrongAttemptsLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 300, height: 40))
        passcodeWrongAttemptsLabel.text = ""
        passcodeWrongAttemptsLabel.textColor = UIColor.red
        passcodeWrongAttemptsLabel.textAlignment = .center
        passcodeWrongAttemptsLabel.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(passcodeWrongAttemptsLabel)
        self.passcodeWrongAttemptsLabel = passcodeWrongAttemptsLabel

        let passcodeTextField =  UITextField(frame: CGRect(x: 0, y: 0, width: 300, height: 40))
        passcodeTextField.borderStyle = UITextBorderStyle.roundedRect
        passcodeTextField.placeholder = "passcode"
        passcodeTextField.isSecureTextEntry = true
        passcodeTextField.clearButtonMode = UITextFieldViewMode.whileEditing
        passcodeTextField.delegate = self
        passcodeTextField.addTarget(self, action: #selector(self.passcodeTextFieldDidChange(_:)), for: UIControlEvents.editingChanged)
        self.view.backgroundColor = UIColor.white
        passcodeTextField.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(passcodeTextField)
        self.passcodeTextField = passcodeTextField

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
                var biometryType = "Touch ID"
                if #available(iOS 11.0, *) {
                    if myContext.biometryType == LABiometryType.faceID {
                        biometryType = "Face ID"
                    }
                }
                biometryAuthButton.setTitle(biometryType, for: .normal)
                biometryAuthButton.isHidden = false
            }
        }

        let cancelButton = UIButton(type: .custom)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(Globals.blue, for: .normal)
        cancelButton.addTarget(self, action: #selector(passcodeLockDidCancel), for: .touchUpInside)
        cancelButton.isHidden = !self.isCancellable
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.contentHorizontalAlignment = UIControlContentHorizontalAlignment.left
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
            passcodeWrongAttemptsLabel.widthAnchor.constraint(equalToConstant: 300),
            passcodeWrongAttemptsLabel.heightAnchor.constraint(equalToConstant: 40),
            passcodeWrongAttemptsLabel.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            passcodeWrongAttemptsLabel.topAnchor.constraint(equalTo: passcodeTextField.bottomAnchor),
            // bottom of the screen
            biometryAuthButton.widthAnchor.constraint(equalToConstant: 150),
            biometryAuthButton.heightAnchor.constraint(equalToConstant: 40),
            biometryAuthButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            biometryAuthButton.bottomAnchor.constraint(equalTo: self.view.safeBottomAnchor, constant: -40),
            // cancel (top-left of the screen)
            cancelButton.widthAnchor.constraint(equalToConstant: 150),
            cancelButton.heightAnchor.constraint(equalToConstant: 40),
            cancelButton.topAnchor.constraint(equalTo: self.view.safeTopAnchor),
            cancelButton.leftAnchor.constraint(equalTo: self.view.safeLeftAnchor, constant: 20)
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
        passcodeFailedAttempts = 0
        passcodeWrongAttemptsLabel?.text = ""
        dismissPasscodeLock(completionHandler: successCallback)
    }

    @objc func passcodeLockDidCancel() {
        dismissPasscodeLock(completionHandler: cancelCallback)
    }

    @objc func bioButtonPressedAction(_ uiButton: UIButton) {
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
                    }
                }
            }
        }
    }

    public override func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == passcodeTextField {
            if !PasscodeLock.shared.check(passcode: textField.text ?? "") {
                passcodeFailedAttempts = passcodeFailedAttempts + 1
                if passcodeFailedAttempts == 1 {
                    passcodeWrongAttemptsLabel?.text = "1 wrong attempt"
                } else {
                    passcodeWrongAttemptsLabel?.text = "\(passcodeFailedAttempts) wrong attempts"
                }
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
