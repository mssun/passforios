//
//  PGPKeySettingTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 21/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import passKit

class PGPKeySettingTableViewController: UITableViewController {

    @IBOutlet weak var pgpPublicKeyURLTextField: UITextField!
    @IBOutlet weak var pgpPrivateKeyURLTextField: UITextField!
    var pgpPassphrase: String?
    let passwordStore = PasswordStore.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableViewAutomaticDimension
        pgpPublicKeyURLTextField.text = SharedDefaults[.pgpPublicKeyURL]?.absoluteString
        pgpPrivateKeyURLTextField.text = SharedDefaults[.pgpPrivateKeyURL]?.absoluteString
        pgpPassphrase = passwordStore.pgpKeyPassphrase
    }
    
    private func validatePGPKeyURL(input: String?) -> Bool {
        guard let path = input, let url = URL(string: path) else {
            Utils.alert(title: "Cannot Save PGP Key", message: "Please set PGP Key URL first.", controller: self, completion: nil)
            return false
        }
        guard let scheme = url.scheme, scheme == "https", scheme == "https"  else {
            Utils.alert(title: "Cannot Save PGP Key", message: "HTTP connection is not supported.", controller: self, completion: nil)
            return false
        }
        return true
    }
    
    @IBAction func save(_ sender: Any) {
        guard validatePGPKeyURL(input: pgpPublicKeyURLTextField.text) == true,
            validatePGPKeyURL(input: pgpPrivateKeyURLTextField.text) == true else {
                return
        }
        let savePassphraseAlert = UIAlertController(title: "Passphrase", message: "Do you want to save the passphrase for later decryption?", preferredStyle: UIAlertControllerStyle.alert)
        // no
        savePassphraseAlert.addAction(UIAlertAction(title: "No", style: UIAlertActionStyle.default) { _ in
            self.pgpPassphrase = nil
            SharedDefaults[.isRememberPGPPassphraseOn] = false
            self.performSegue(withIdentifier: "savePGPKeySegue", sender: self)
        })
        // yes
        savePassphraseAlert.addAction(UIAlertAction(title: "Yes", style: UIAlertActionStyle.destructive) {_ in
            // ask for the passphrase
            let alert = UIAlertController(title: "Passphrase", message: "Please fill in the passphrase of your PGP secret key.", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {_ in
                self.pgpPassphrase = alert.textFields?.first?.text
                SharedDefaults[.isRememberPGPPassphraseOn] = true
                self.performSegue(withIdentifier: "savePGPKeySegue", sender: self)
            }))
            alert.addTextField(configurationHandler: {(textField: UITextField!) in
                textField.text = self.pgpPassphrase
                textField.isSecureTextEntry = true
            })
            self.present(alert, animated: true, completion: nil)
        })
        self.present(savePassphraseAlert, animated: true, completion: nil)
    }
}
