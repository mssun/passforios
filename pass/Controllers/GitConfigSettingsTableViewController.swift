//
//  GitConfigSettingsTableViewController.swift
//  pass
//
//  Created by Yishi Lin on 10/4/17.
//  Copyright © 2017 Yishi Lin. All rights reserved.
//

import passKit
import UIKit

class GitConfigSettingsTableViewController: UITableViewController {
    let passwordStore = PasswordStore.shared

    @IBOutlet var nameTextField: UITextField!
    @IBOutlet var emailTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableView.automaticDimension

        let signature = passwordStore.gitSignatureForNow
        nameTextField.placeholder = signature?.name ?? ""
        emailTextField.placeholder = signature?.email ?? ""
        nameTextField.text = Defaults.gitSignatureName
        emailTextField.text = Defaults.gitSignatureEmail
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender _: Any?) -> Bool {
        if identifier == "saveGitConfigSettingSegue" {
            let name = nameTextField.text!.isEmpty ? Globals.gitSignatureDefaultName : nameTextField.text!
            let email = emailTextField.text!.isEmpty ? Globals.gitSignatureDefaultEmail : nameTextField.text!
            guard GTSignature(name: name, email: email, time: nil) != nil else {
                Utils.alert(title: "Error".localize(), message: "InvalidNameOrEmail".localize(), controller: self, completion: nil)
                return false
            }
        }
        return true
    }
}
