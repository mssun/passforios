//
//  SSHKeySettingTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 25/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import SwiftyUserDefaults
import SVProgressHUD

class SSHKeySettingTableViewController: UITableViewController {

    @IBOutlet weak var privateKeyURLTextField: UITextField!
    @IBOutlet weak var publicKeyURLTextField: UITextField!
    let passwordStore = PasswordStore.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        privateKeyURLTextField.text = Defaults[.gitSSHPrivateKeyURL]?.absoluteString
        publicKeyURLTextField.text = Defaults[.gitSSHPublicKeyURL]?.absoluteString
    }
    
    
    @IBAction func doneButtonTapped(_ sender: UIButton) {
        guard let publicKeyURL = URL(string: publicKeyURLTextField.text!) else {
            Utils.alert(title: "Cannot Save", message: "Please set Public Key URL first.", controller: self, completion: nil)
            return
        }
        guard let privateKeyURL = URL(string: privateKeyURLTextField.text!) else {
            Utils.alert(title: "Cannot Save", message: "Please set Private Key URL first.", controller: self, completion: nil)
            return
        }
        
        Defaults[.gitSSHPublicKeyURL] = publicKeyURL
        Defaults[.gitSSHPrivateKeyURL] = privateKeyURL
        
        do {
            try Data(contentsOf: publicKeyURL).write(to: URL(fileURLWithPath: Globals.gitSSHPublicKeyPath), options: .atomic)
            try Data(contentsOf: privateKeyURL).write(to: URL(fileURLWithPath: Globals.gitSSHPrivateKeyPath), options: .atomic)
        } catch {
            Utils.alert(title: "Error", message: error.localizedDescription, controller: self, completion: nil)
        }
        Defaults[.gitSSHKeySource] = "url"
        let alert = UIAlertController(
            title: "PGP Passphrase",
            message: "Please fill in the passphrase for your Git Repository SSH key.",
            preferredStyle: UIAlertControllerStyle.alert
        )
        
        alert.addAction(
            UIAlertAction(
                title: "OK",
                style: UIAlertActionStyle.default,
                handler: {_ in
                    Utils.addPasswordToKeychain(
                        name: "gitSSHPrivateKeyPassphrase",
                        password: alert.textFields!.first!.text!
                    )
                    self.navigationController!.popViewController(animated: true)
            }
            )
        )
        
        alert.addTextField(
            configurationHandler: {(textField: UITextField!) in
                textField.text = self.passwordStore.gitSSHPrivateKeyPassphrase
                textField.isSecureTextEntry = true
        })
        self.present(alert, animated: true, completion: nil)
    }

}
