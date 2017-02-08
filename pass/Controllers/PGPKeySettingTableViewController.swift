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

    @IBOutlet weak var pgpKeyURLTextField: UITextField!
    @IBOutlet weak var pgpKeyPassphraseTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        pgpKeyURLTextField.text = Defaults[.pgpKeyURL]?.absoluteString
        pgpKeyPassphraseTextField.text = Defaults[.pgpKeyPassphrase]
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "savePGPKeySegue" {
            if URL(string: pgpKeyURLTextField.text!)!.scheme! == "http" {
                let alertMessage = "HTTP connection is not supported."
                let alert = UIAlertController(title: "Cannot Save Settings", message: alertMessage, preferredStyle: UIAlertControllerStyle.alert)
                alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                self.present(alert, animated: true, completion: nil)
                return false
            }
        }
        return true
    }
}
