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
        tableData = [
            [[.type: CellDataType.segue, .title: "Git Server", .link: "showGitServerSettingSegue"],
             [.type: CellDataType.segue, .title: "SSH Key", .link: "showSSHKeySettingSegue"],],
        ]
        navigationItemTitle = "Repository"
        super.viewDidLoad()
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
