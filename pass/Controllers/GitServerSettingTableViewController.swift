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
    @IBOutlet weak var authSSHKeyCell: UITableViewCell!
    @IBOutlet weak var authPasswordCell: UITableViewCell!
    var password: String?
    
    var authenticationMethod = Defaults[.gitRepositoryAuthenticationMethod]

    private func checkAuthenticationMethod(method: String) {
        let passwordCheckView = authPasswordCell.viewWithTag(1001)!
        let sshKeyCheckView = authSSHKeyCell.viewWithTag(1001)!

        switch method {
        case "Password":
            passwordCheckView.isHidden = false
            sshKeyCheckView.isHidden = true
        case "SSH Key":
            passwordCheckView.isHidden = true
            sshKeyCheckView.isHidden = false
        default:
            passwordCheckView.isHidden = false
            sshKeyCheckView.isHidden = true
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        if let url = Defaults[.gitRepositoryURL] {
            gitRepositoryURLTextField.text = url.absoluteString
        }
        usernameTextField.text = Defaults[.gitRepositoryUsername]
        password = PasswordStore.shared.gitRepositoryPassword
        authenticationMethod = Defaults[.gitRepositoryAuthenticationMethod]
        if authenticationMethod == nil {
            authenticationMethod = "Password"
        }
        checkAuthenticationMethod(method: authenticationMethod!)
        authSSHKeyCell.accessoryType = .detailButton
    }
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        if cell == authSSHKeyCell {
            performSegue(withIdentifier: "showSSHKeySettingSegue", sender: self)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
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
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        if cell == authPasswordCell {
            authenticationMethod = "Password"
        } else if cell == authSSHKeyCell {
            if Defaults[.gitRepositorySSHPublicKeyURL] == nil && Defaults[.gitRepositorySSHPrivateKeyURL] == nil {
                Utils.alert(title: "Cannot Select SSH Key", message: "Please setup SSH key first.", controller: self, completion: nil)
                authenticationMethod = "Password"
            } else {
                authenticationMethod = "SSH Key"
            }
        }
        checkAuthenticationMethod(method: authenticationMethod!)
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    @IBAction func save(_ sender: Any) {
        if authenticationMethod == "Password" {
            let alert = UIAlertController(title: "Password", message: "Please fill in the password of your Git account.", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {_ in
                self.password = alert.textFields!.first!.text
                if self.shouldPerformSegue(withIdentifier: "saveGitServerSettingSegue", sender: self) {
                    self.performSegue(withIdentifier: "saveGitServerSettingSegue", sender: self)
                }
            }))
            alert.addTextField(configurationHandler: {(textField: UITextField!) in
                textField.text = self.password
                textField.isSecureTextEntry = true
            })
            self.present(alert, animated: true, completion: nil)
        } else {
            if self.shouldPerformSegue(withIdentifier: "saveGitServerSettingSegue", sender: self) {
                self.performSegue(withIdentifier: "saveGitServerSettingSegue", sender: self)
            }
        }
    }
}
