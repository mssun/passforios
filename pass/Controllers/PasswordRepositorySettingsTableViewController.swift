//
//  PasswordRepositorySettingsTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 9/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import SwiftyUserDefaults
import SVProgressHUD

class PasswordRepositorySettingsTableViewController: BasicStaticTableViewController {
    override func viewDidLoad() {
        let url = Defaults[.gitRepositoryURL]?.host
        tableData = [
            [[.style: CellDataStyle.value1, .title: "Git Server", .action: "segue", .link: "showGitServerSettingSegue", .detailText: url ?? ""],
             [.style: CellDataStyle.value1, .title: "SSH Key", .action: "segue", .link: "showSSHKeySettingSegue", .detailText: "Not Set"],],
        ]
        navigationItemTitle = "Repository"
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let url = Defaults[.gitRepositoryURL] {
            if let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) {
                cell.detailTextLabel!.text = url.host
            }
        }
        if Defaults[.gitRepositorySSHPublicKeyURL] != nil {
            if let cell = tableView.cellForRow(at: IndexPath(row: 1, section: 0)) {
                cell.detailTextLabel!.text = "Set"
            }
        }
    }
    
    
    @IBAction func cancelGitServerSetting(segue: UIStoryboardSegue) {
    }
    
    @IBAction func saveGitServerSetting(segue: UIStoryboardSegue) {
        if let controller = segue.source as? GitServerSettingTableViewController {
            let gitRepostiroyURL = controller.gitRepositoryURLTextField.text!
            let username = controller.usernameTextField.text!
            let password = controller.passwordTextField.text!
            let auth = controller.authenticationMethod
            
            if Defaults[.gitRepositoryURL] == nil || gitRepostiroyURL != Defaults[.gitRepositoryURL]!.absoluteString {
                SVProgressHUD.setDefaultMaskType(.black)
                SVProgressHUD.setDefaultStyle(.light)
                SVProgressHUD.show(withStatus: "Prepare Repository")
                var gitCredential: GitCredential
                if auth == "Password" {
                    gitCredential = GitCredential(credential: GitCredential.Credential.http(userName: username, password: password))
                } else {
                    gitCredential = GitCredential(credential: GitCredential.Credential.ssh(userName: username, password: Defaults[.gitRepositorySSHPrivateKeyPassphrase]!, publicKeyFile: Globals.sshPublicKeyURL, privateKeyFile: Globals.sshPrivateKeyURL))
                }
                
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try PasswordStore.shared.cloneRepository(remoteRepoURL: URL(string: gitRepostiroyURL)!,
                                                                 credential: gitCredential,
                                                                 transferProgressBlock:{ (git_transfer_progress, stop) in
                                                                    DispatchQueue.main.async {
                                                                        SVProgressHUD.showProgress(Float(git_transfer_progress.pointee.received_objects)/Float(git_transfer_progress.pointee.total_objects), status: "Clone Remote Repository")
                                                                    }
                        },
                                                                 checkoutProgressBlock: { (path, completedSteps, totalSteps) in
                                                                    DispatchQueue.main.async {
                                                                        SVProgressHUD.showProgress(Float(completedSteps)/Float(totalSteps), status: "Checkout Master Branch")
                                                                    }
                        })
                        
                        DispatchQueue.main.async {
                            SVProgressHUD.showSuccess(withStatus: "Done")
                            SVProgressHUD.dismiss(withDelay: 1)
                            
                            Defaults[.lastUpdatedTime] = Date()
                            
                            NotificationCenter.default.post(Notification(name: Notification.Name("passwordUpdated")))
                            
                        }
                    } catch {
                        DispatchQueue.main.async {
                            print(error)
                            SVProgressHUD.showError(withStatus: error.localizedDescription)
                            SVProgressHUD.dismiss(withDelay: 1)
                        }
                    }
                    
                }
            }
            
            Defaults[.gitRepositoryURL] = URL(string: gitRepostiroyURL)
            Defaults[.gitRepositoryUsername] = username
            Defaults[.gitRepositoryPassword] = password
            Defaults[.gitRepositoryAuthenticationMethod] = auth
        }
    }
}
