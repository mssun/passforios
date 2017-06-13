//
//  GitCredential.swift
//  pass
//
//  Created by Mingshen Sun on 30/4/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import UIKit
import SwiftyUserDefaults
import ObjectiveGit
import SVProgressHUD

public struct GitCredential {
    public var credential: Credential
    
    public enum Credential {
        case http(userName: String, controller: UIViewController)
        case ssh(userName: String, privateKeyFile: URL, controller: UIViewController)
    }
    
    public init(credential: Credential) {
        self.credential = credential
    }
    
    public func credentialProvider() throws -> GTCredentialProvider {
        var attempts = 0
        var lastPassword: String? = nil
        return GTCredentialProvider { (_, _, _) -> (GTCredential?) in
            var credential: GTCredential? = nil
            
            switch self.credential {
            case let .http(userName, controller):
                var newPassword = Utils.getPasswordFromKeychain(name: "gitPassword")
                if newPassword == nil || attempts != 0 {
                    if let requestedPassword = self.requestGitPassword(controller, lastPassword) {
                        newPassword	= requestedPassword
                        Utils.addPasswordToKeychain(name: "gitPassword", password: newPassword)
                    } else {
                        return nil
                    }
                }
                attempts += 1
                lastPassword = newPassword
                credential = try? GTCredential(userName: userName, password: newPassword!)
            case let .ssh(userName, privateKeyFile, controller):
                var newPassword = Utils.getPasswordFromKeychain(name: "gitSSHKeyPassphrase")
                if newPassword == nil || attempts != 0  {
                    if let requestedPassword = self.requestGitPassword(controller, lastPassword) {
                        newPassword	= requestedPassword
                        Utils.addPasswordToKeychain(name: "gitSSHKeyPassphrase", password: newPassword)
                    } else {
                        return nil
                    }
                }
                attempts += 1
                lastPassword = newPassword
                credential = try? GTCredential(userName: userName, publicKeyURL: nil, privateKeyURL: privateKeyFile, passphrase: newPassword!)
                print(privateKeyFile)
            }
            return credential
        }
    }
    
    public func delete() {
        switch credential {
        case .http:
            Utils.removeKeychain(name: "gitPassword")
        case .ssh:
            Utils.removeKeychain(name: "gitSSHKeyPassphrase")
        }
    }
    
    private func requestGitPassword(_ controller: UIViewController, _ lastPassword: String?) -> String? {
        let sem = DispatchSemaphore(value: 0)
        var password: String?
        var message = ""
        switch credential {
        case .http:
            message = "Please fill in the password of your Git account."
        case .ssh:
            message = "Please fill in the password of your SSH key."
        }
        
        DispatchQueue.main.async {
            SVProgressHUD.dismiss()
            let alert = UIAlertController(title: "Password", message: message, preferredStyle: UIAlertControllerStyle.alert)
            alert.addTextField(configurationHandler: {(textField: UITextField!) in
                textField.text = lastPassword ?? ""
                textField.isSecureTextEntry = true
            })
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {_ in
                password = alert.textFields!.first!.text
                sem.signal()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                password = nil
                sem.signal()
            })
            controller.present(alert, animated: true, completion: nil)
        }
        
        let _ = sem.wait(timeout: .distantFuture)
        return password
    }
}

