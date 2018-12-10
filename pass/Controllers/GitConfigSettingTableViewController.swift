//
//  GitConfigSettingTableViewController.swift
//  pass
//
//  Created by Yishi Lin on 10/4/17.
//  Copyright © 2017 Yishi Lin. All rights reserved.
//

import UIKit
import SwiftyUserDefaults
import passKit

class GitConfigSettingTableViewController: UITableViewController {
    let passwordStore = PasswordStore.shared

    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableViewAutomaticDimension

        let signature = passwordStore.gitSignatureForNow
        nameTextField.placeholder = signature.name
        emailTextField.placeholder = signature.email
        nameTextField.text = SharedDefaults[.gitSignatureName]
        emailTextField.text = SharedDefaults[.gitSignatureEmail]
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "saveGitConfigSettingSegue" {
            let name = nameTextField.text!.isEmpty ? Globals.gitSignatureDefaultName : nameTextField.text!
            let email = emailTextField.text!.isEmpty ? Globals.gitSignatureDefaultEmail : nameTextField.text!
            guard GTSignature(name: name, email: email, time: nil) != nil else {
                Utils.alert(title: "Error", message: "Invalid name or email.", controller: self, completion: nil)
                return false
            }
        }
        return true
    }
}

