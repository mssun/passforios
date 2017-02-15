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
    @IBOutlet weak var pgpKeyPassphraseTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        pgpPublicKeyURLTextField.text = Defaults[.pgpPublicKeyURL]?.absoluteString
        pgpPrivateKeyURLTextField.text = Defaults[.pgpPrivateKeyURL]?.absoluteString
        pgpKeyPassphraseTextField.text = Defaults[.pgpKeyPassphrase]
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "savePGPKeySegue" {
            guard pgpPublicKeyURLTextField.text != nil else {
                return false
            }
            guard pgpPrivateKeyURLTextField.text != nil else {
                return false
            }
            
            guard URL(string: pgpPublicKeyURLTextField.text!) != nil else {
                Utils.alert(title: "Cannot Save", message: "Please set Public Key URL first.", controller: self, completion: nil)
                return false
            }
            guard URL(string: pgpPrivateKeyURLTextField.text!) != nil else {
                Utils.alert(title: "Cannot Save", message: "Please set Private Key URL first.", controller: self, completion: nil)
                return false
            }
            
            if URL(string: pgpPublicKeyURLTextField.text!)!.scheme! == "http" &&
                URL(string: pgpPrivateKeyURLTextField.text!)!.scheme! == "http" {
                Utils.alert(title: "Cannot Save Settings", message: "HTTP connection is not supported.", controller: self, completion: nil)
                return false
            }
        }
        return true
    }
}
