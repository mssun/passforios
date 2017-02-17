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
    @IBOutlet weak var passphraseTextField: UITextField!
    @IBOutlet weak var armorPrivateKeyTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        armorPublicKeyTextView.text = Defaults[.pgpPublicKeyArmor]
        armorPrivateKeyTextView.text = Defaults[.pgpPrivateKeyArmor]
        passphraseTextField.text = Defaults[.pgpKeyPassphrase]
    }

}
