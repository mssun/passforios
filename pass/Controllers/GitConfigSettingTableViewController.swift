//
//  GitConfigSettingTableViewController.swift
//  pass
//
//  Created by Yishi Lin on 10/4/17.
//  Copyright © 2017 Yishi Lin. All rights reserved.
//

import UIKit
import SwiftyUserDefaults

class GitConfigSettingTableViewController: UITableViewController {
    
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableViewAutomaticDimension
        nameTextField.text = Defaults[.gitName]
        emailTextField.text = Defaults[.gitEmail]
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "saveGitConfigSettingSegue" {
            guard let name = nameTextField.text, !name.isEmpty else {
                Utils.alert(title: "Cannot Save", message: "Please set name first.", controller: self, completion: nil)
                return false
            }
            guard let email = emailTextField.text, !email.isEmpty else {
                Utils.alert(title: "Cannot Save", message: "Please set email first.", controller: self, completion: nil)
                return false
            }
        }
        return true
    }
}

