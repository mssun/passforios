//
//  PGPKeyArmorSettingTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 17/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import SwiftyUserDefaults

class PGPKeyArmorSettingTableViewController: UITableViewController {
    @IBOutlet weak var armorPublicKeyTextView: UITextView!
    @IBOutlet weak var armorPrivateKeyTextView: UITextView!
    var pgpPassphrase: String?
    let passwordStore = PasswordStore.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        armorPublicKeyTextView.text = Defaults[.pgpPublicKeyArmor]
        armorPrivateKeyTextView.text = Defaults[.pgpPrivateKeyArmor]
        pgpPassphrase = passwordStore.pgpKeyPassphrase
    }
    
    private func createSavePassphraseAlert() -> UIAlertController {
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
    
    @IBAction func save(_ sender: Any) {
        let alert = UIAlertController(title: "Passphrase", message: "Please fill in the passphrase of your PGP secret key.", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {_ in
            self.pgpPassphrase = alert.textFields?.first?.text
            let savePassphraseAlert = self.createSavePassphraseAlert()
            self.present(savePassphraseAlert, animated: true, completion: nil)
        }))
        alert.addTextField(configurationHandler: {(textField: UITextField!) in
            textField.text = self.pgpPassphrase
            textField.isSecureTextEntry = true
        })
        self.present(alert, animated: true, completion: nil)
    }

}
