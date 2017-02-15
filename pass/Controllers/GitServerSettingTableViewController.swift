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
    
    var authenticationMethod = Defaults[.gitRepositoryAuthenticationMethod]

    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let url = Defaults[.gitRepositoryURL] {
            gitRepositoryURLTextField.text = url.absoluteString
        }
        usernameTextField.text = Defaults[.gitRepositoryUsername]
        passwordTextField.text = Defaults[.gitRepositoryPassword]
        authenticationTableViewCell.detailTextLabel?.text = authenticationMethod
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if authenticationMethod == "SSH Key" {
            if Defaults[.gitRepositorySSHPublicKeyURL] == nil && Defaults[.gitRepositorySSHPrivateKeyURL] == nil {
                authenticationMethod = "Password"
                Utils.alert(title: "Cannot Select SSH Key", message: "Please setup SSH key first.", controller: self, completion: nil)
            } else {
                authenticationMethod = "SSH Key"
            }
        }
        authenticationTableViewCell.detailTextLabel?.text = authenticationMethod
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "saveGitServerSettingSegue" {
            if gitRepositoryURLTextField.text == "" || authenticationMethod == nil {
                var alertMessage = ""
                if gitRepositoryURLTextField.text == "" {
                    alertMessage = "Git Server is not set. Please set the Git server first."
                }
                if authenticationMethod == nil {
                    alertMessage = "Authentication method is not set. Please set your authentication method first."
                }
                Utils.alert(title: "Cannot Save Settings", message: alertMessage, controller: self, completion: nil)
                return false
            }
        }
        return true
    }
    
    @IBAction func save(segue: UIStoryboardSegue) {
        if let controller = segue.source as? UITableViewController {
            if controller.tableView.indexPathForSelectedRow == IndexPath(row: 0, section:0) {
                authenticationMethod = "Password"
            } else {
                authenticationMethod = "SSH Key"
            }
        }
        authenticationTableViewCell.detailTextLabel?.text = authenticationMethod
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "selectAuthenticationMethod" {
            if let controller = segue.destination as? GitRepositoryAuthenticationSettingTableViewController {
                controller.selectedMethod = authenticationTableViewCell.detailTextLabel!.text
            }
        }
    }
}
