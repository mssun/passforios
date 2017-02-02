//
//  SettingsTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 18/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import SVProgressHUD
import CoreData
import SwiftyUserDefaults

class SettingsTableViewController: UITableViewController {
        
    @IBOutlet weak var pgpKeyTableViewCell: UITableViewCell!
    
    @IBAction func cancel(segue: UIStoryboardSegue) {
    }
    
    @IBAction func save(segue: UIStoryboardSegue) {
        if let controller = segue.source as? GitServerSettingTableViewController {
            let gitRepostiroyURL = controller.gitRepositoryURLTextField.text!
            let username = controller.usernameTextField.text!
            let password = controller.passwordTextField.text!
            let auth = controller.authenticationMethod

            
            
            if Defaults[.gitRepositoryURL] == nil || gitRepostiroyURL != Defaults[.gitRepositoryURL]!.absoluteString {
                SVProgressHUD.setDefaultMaskType(.black)
                SVProgressHUD.show(withStatus: "Prepare Repository")
                var gitCredential: GitCredential
                if auth == "Password" {
                    gitCredential = GitCredential(credential: GitCredential.Credential.http(userName: username, password: password))
                } else {
                    gitCredential = GitCredential(credential: GitCredential.Credential.ssh(userName: username, password: Defaults[.gitRepositorySSHPrivateKeyPassphrase]!, publicKeyFile: Globals.shared.sshPublicKeyPath, privateKeyFile: Globals.shared.sshPrivateKeyPath))
                }

                DispatchQueue.global(qos: .userInitiated).async {
                    let ret = PasswordStore.shared.cloneRepository(remoteRepoURL: URL(string: gitRepostiroyURL)!,
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
                        if ret {
                            SVProgressHUD.showSuccess(withStatus: "Done")
                            SVProgressHUD.dismiss(withDelay: 1)
                            
                            Defaults[.gitRepositoryURL] = URL(string: gitRepostiroyURL)
                            Defaults[.gitRepositoryUsername] = username
                            Defaults[.gitRepositoryPassword] = password
                            Defaults[.gitRepositoryAuthenticationMethod] = auth

                            NotificationCenter.default.post(Notification(name: Notification.Name("passwordUpdated")))
                        } else {
                            SVProgressHUD.showError(withStatus: "Error")
                            SVProgressHUD.dismiss(withDelay: 1)
                        }
                    }
                }
            }
        } else if let controller = segue.source as? PGPKeySettingTableViewController {
            if Defaults[.pgpKeyURL] != URL(string: controller.pgpKeyURLTextField.text!) {
                Defaults[.pgpKeyURL] = URL(string: controller.pgpKeyURLTextField.text!)
                Defaults[.pgpKeyPassphrase] = controller.pgpKeyPassphraseTextField.text!
                
                SVProgressHUD.setDefaultMaskType(.black)
                SVProgressHUD.show(withStatus: "Fetching PGP Key")
                DispatchQueue.global(qos: .userInitiated).async {
                    let ret = PasswordStore.shared.initPGP(pgpKeyURL: Defaults[.pgpKeyURL]!, pgpKeyLocalPath: Globals.shared.secringPath)
                    
                    DispatchQueue.main.async {
                        if ret {
                            SVProgressHUD.showSuccess(withStatus: "Success")
                        } else {
                            SVProgressHUD.showError(withStatus: "Error")
                    }
                    }
                }
            }
            
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if Defaults[.pgpKeyID] == "" {
            pgpKeyTableViewCell.detailTextLabel?.text = "Not Set"
        } else {
            pgpKeyTableViewCell.detailTextLabel?.text = Defaults[.pgpKeyID]
        }
    }
}
