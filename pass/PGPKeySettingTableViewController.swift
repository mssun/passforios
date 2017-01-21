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
}
