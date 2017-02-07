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
                            SVProgressHUD.dismiss(withDelay: 3)
                        }
                    }
                    
                }
            }
            
            Defaults[.gitRepositoryURL] = URL(string: gitRepostiroyURL)
            Defaults[.gitRepositoryUsername] = username
            Defaults[.gitRepositoryPassword] = password
            Defaults[.gitRepositoryAuthenticationMethod] = auth
        } else if let controller = segue.source as? PGPKeySettingTableViewController {

            if Defaults[.pgpKeyURL] != URL(string: controller.pgpKeyURLTextField.text!) ||
                Defaults[.pgpKeyPassphrase] != controller.pgpKeyPassphraseTextField.text! {
                Defaults[.pgpKeyURL] = URL(string: controller.pgpKeyURLTextField.text!)
                Defaults[.pgpKeyPassphrase] = controller.pgpKeyPassphraseTextField.text!
                
                SVProgressHUD.setDefaultMaskType(.black)
                SVProgressHUD.show(withStatus: "Fetching PGP Key")
                DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
                    do {
                        try PasswordStore.shared.initPGP(pgpKeyURL: Defaults[.pgpKeyURL]!, pgpKeyLocalPath: Globals.shared.secringPath)
                        DispatchQueue.main.async {
                            self.pgpKeyTableViewCell.detailTextLabel?.text = Defaults[.pgpKeyID]
                            SVProgressHUD.showSuccess(withStatus: "Success. Remember to remove the key from the server.")
                            SVProgressHUD.dismiss(withDelay: 1)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            SVProgressHUD.showError(withStatus: error.localizedDescription)
                            SVProgressHUD.dismiss(withDelay: 3)
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
