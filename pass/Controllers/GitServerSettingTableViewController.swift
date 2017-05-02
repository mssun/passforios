//
//  GitServerSettingTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 21/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import SwiftyUserDefaults
import SVProgressHUD

class GitServerSettingTableViewController: UITableViewController {

    @IBOutlet weak var gitURLTextField: UITextField!
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var authSSHKeyCell: UITableViewCell!
    @IBOutlet weak var authPasswordCell: UITableViewCell!
    let passwordStore = PasswordStore.shared
    var sshLabel: UILabel? = nil

    var authenticationMethod = Defaults[.gitAuthenticationMethod] ?? "Password"

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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Grey out ssh option if ssh_key and ssh_key.pub are not present
        sshLabel = authSSHKeyCell.subviews[0].subviews[0] as? UILabel
        sshLabel!.isEnabled = gitSSHKeyExists()

    }
    override func viewDidLoad() {
        super.viewDidLoad()
        if let url = Defaults[.gitURL] {
            gitURLTextField.text = url.absoluteString
        }
        usernameTextField.text = Defaults[.gitUsername]

        checkAuthenticationMethod(method: authenticationMethod)
        authSSHKeyCell.accessoryType = .detailButton
    }
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        if cell == authSSHKeyCell {
            showSSHKeyActionSheet()
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
            guard let _ = URL(string: gitURLTextField.text!) else {
                Utils.alert(title: "Cannot Save", message: "Git Server is not set.", controller: self, completion: nil)
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

            if !gitSSHKeyExists() {
                Utils.alert(title: "Cannot Select SSH Key", message: "Please setup SSH key first.", controller: self, completion: nil)
                authenticationMethod = "Password"
            } else {
                authenticationMethod = "SSH Key"
            }
        }
        checkAuthenticationMethod(method: authenticationMethod)
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    private func doClone() {
        if self.shouldPerformSegue(withIdentifier: "saveGitServerSettingSegue", sender: self) {
            self.performSegue(withIdentifier: "saveGitServerSettingSegue", sender: self)
        }
    }
    
    @IBAction func save(_ sender: Any) {
        if passwordStore.repositoryExisted() {
            let alert = UIAlertController(title: "Erase Current Password Store Data?", message: "A cloned password store exists. This operation will erase all local data. Data on your remote server will not be affected.", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "Erase", style: UIAlertActionStyle.destructive, handler: { _ in
                self.doClone()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        } else {
            doClone()
        }
    }
    
    private func gitSSHKeyExists() -> Bool {
        return FileManager.default.fileExists(atPath: Globals.gitSSHPublicKeyPath) &&
            FileManager.default.fileExists(atPath: Globals.gitSSHPrivateKeyPath)
    }
    
    func showSSHKeyActionSheet() {
        let optionMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        var urlActionTitle = "Download from URL"
        var armorActionTitle = "ASCII-Armor Encrypted Key"
        var fileActionTitle = "Use Uploaded Keys"
        
        if Defaults[.gitSSHKeySource] == "url" {
            urlActionTitle = "✓ \(urlActionTitle)"
        } else if Defaults[.gitSSHKeySource] == "armor" {
            armorActionTitle = "✓ \(armorActionTitle)"
        } else if Defaults[.gitSSHKeySource] == "file" {
            fileActionTitle = "✓ \(fileActionTitle)"
        }
        let urlAction = UIAlertAction(title: urlActionTitle, style: .default) { _ in
            self.performSegue(withIdentifier: "setGitSSHKeyByURLSegue", sender: self)
        }
        let armorAction = UIAlertAction(title: armorActionTitle, style: .default) { _ in
            self.performSegue(withIdentifier: "setGitSSHKeyByArmorSegue", sender: self)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        optionMenu.addAction(urlAction)
        optionMenu.addAction(armorAction)
        
        if (gitSSHKeyExists()) {
            let fileAction = UIAlertAction(title: fileActionTitle, style: .default) { _ in
                Defaults[.gitSSHKeySource] = "file"
            }
            optionMenu.addAction(fileAction)
        }
        
        if Defaults[.gitSSHKeySource] != nil {
            let deleteAction = UIAlertAction(title: "Remove Git SSH Keys", style: .destructive) { _ in
                Utils.removeGitSSHKeys()
                Defaults[.gitSSHKeySource] = nil
                self.sshLabel!.isEnabled = false
            }
            optionMenu.addAction(deleteAction)
        }
        optionMenu.addAction(cancelAction)
        optionMenu.popoverPresentationController?.sourceView = authSSHKeyCell
        optionMenu.popoverPresentationController?.sourceRect = authSSHKeyCell.bounds
        self.present(optionMenu, animated: true, completion: nil)
    }
}
