//
//  PGPKeySettingTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 21/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import SwiftyUserDefaults

class PGPKeySettingTableViewController: UITableViewController {

    @IBOutlet weak var pgpPublicKeyURLTextField: UITextField!
    @IBOutlet weak var pgpPrivateKeyURLTextField: UITextField!
    var pgpPassphrase: String?
    let passwordStore = PasswordStore.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableViewAutomaticDimension
        pgpPublicKeyURLTextField.text = Defaults[.pgpPublicKeyURL]?.absoluteString
        pgpPrivateKeyURLTextField.text = Defaults[.pgpPrivateKeyURL]?.absoluteString
        pgpPassphrase = passwordStore.pgpKeyPassphrase
    }
    
    private func createSavePassphraseAndSegueAlert() -> UIAlertController {
        let savePassphraseAlert = UIAlertController(title: "Passphrase", message: "Do you want to save the passphrase for later decryption?", preferredStyle: UIAlertControllerStyle.alert)
        savePassphraseAlert.addAction(UIAlertAction(title: "No", style: UIAlertActionStyle.default) { _ in
            Defaults[.isRememberPassphraseOn] = false
            self.performSegue(withIdentifier: "savePGPKeySegue", sender: self)
        })
        savePassphraseAlert.addAction(UIAlertAction(title: "Save", style: UIAlertActionStyle.destructive) {_ in
            Defaults[.isRememberPassphraseOn] = true
            self.performSegue(withIdentifier: "savePGPKeySegue", sender: self)
        })
        return savePassphraseAlert
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "savePGPKeySegue" {
            guard let pgpPublicKeyURL = URL(string: pgpPublicKeyURLTextField.text!) else {
                Utils.alert(title: "Cannot Save", message: "Please set Public Key URL first.", controller: self, completion: nil)
                return false
            }
            guard let pgpPrivateKeyURL = URL(string: pgpPrivateKeyURLTextField.text!) else {
                Utils.alert(title: "Cannot Save", message: "Please set Private Key URL first.", controller: self, completion: nil)
                return false
            }
            guard pgpPublicKeyURL.scheme! == "https", pgpPrivateKeyURL.scheme! == "https"  else {
                Utils.alert(title: "Cannot Save Settings", message: "HTTP connection is not supported.", controller: self, completion: nil)
                return false
            }
        }
        return true
    }
    
    @IBAction func save(_ sender: Any) {
        let alert = UIAlertController(title: "Passphrase", message: "Please fill in the passphrase of your PGP secret key.", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {_ in
            self.pgpPassphrase = alert.textFields?.first?.text
            let savePassphraseAndSegueAlert = self.createSavePassphraseAndSegueAlert()
            self.present(savePassphraseAndSegueAlert, animated: true, completion: nil)
        }))
        alert.addTextField(configurationHandler: {(textField: UITextField!) in
            textField.text = self.pgpPassphrase
            textField.isSecureTextEntry = true
        })
        self.present(alert, animated: true, completion: nil)
    }
}
