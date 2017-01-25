//
//  GitServerSettingTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 21/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import SwiftyUserDefaults

class GitServerSettingTableViewController: UITableViewController {

    @IBOutlet weak var gitRepositoryURLTextField: UITextField!
    
    @IBOutlet weak var usernameTextField: UITextField!
    
    @IBOutlet weak var passwordTextField: UITextField!
    
    @IBOutlet weak var authenticationTableViewCell: UITableViewCell!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let url = Defaults[.gitRepositoryURL] {
            gitRepositoryURLTextField.text = url.absoluteString
        }
        usernameTextField.text = Defaults[.gitRepositoryUsername]
        passwordTextField.text = Defaults[.gitRepositoryPassword]
        authenticationTableViewCell.detailTextLabel?.text = Defaults[.gitRepositoryAuthenticationMethod]
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        gitRepositoryURLTextField.becomeFirstResponder()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
    }
    @IBAction func save(segue: UIStoryboardSegue) {
        if let controller = segue.source as? UITableViewController {
            if controller.tableView.indexPathForSelectedRow == IndexPath(row: 0, section:0) {
                authenticationTableViewCell.detailTextLabel?.text = "Password"
            } else {
                authenticationTableViewCell.detailTextLabel?.text = "SSH Key"
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "selectAuthenticationMethod" {
            if let controller = segue.destination as? GitRepositoryAuthenticationSettingTableViewController {
                controller.selectedMethod = authenticationTableViewCell.detailTextLabel!.text
            }
        }
    }
}
