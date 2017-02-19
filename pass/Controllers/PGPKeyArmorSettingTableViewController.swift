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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        armorPublicKeyTextView.text = Defaults[.pgpPublicKeyArmor]
        armorPrivateKeyTextView.text = Defaults[.pgpPrivateKeyArmor]
        pgpPassphrase = PasswordStore.shared.pgpKeyPassphrase
    }
    
    @IBAction func save(_ sender: Any) {
        let alert = UIAlertController(title: "Phassphrase", message: "Please fill in the passphrase of your PGP secret key.", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {_ in
            self.pgpPassphrase = alert.textFields?.first?.text
            self.performSegue(withIdentifier: "savePGPKeySegue", sender: self)
        }))
        alert.addTextField(configurationHandler: {(textField: UITextField!) in
            textField.text = self.pgpPassphrase
            textField.isSecureTextEntry = true
        })
        self.present(alert, animated: true, completion: nil)
    }

}
