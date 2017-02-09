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
import PasscodeLock

class SettingsTableViewController: UITableViewController {
    
    let touchIDSwitch = UISwitch(frame: CGRect.zero)

    @IBOutlet weak var pgpKeyTableViewCell: UITableViewCell!
    @IBOutlet weak var touchIDTableViewCell: UITableViewCell!
    @IBOutlet weak var passcodeTableViewCell: UITableViewCell!
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
        } else if let controller = segue.source as? PGPKeySettingTableViewController {

            if Defaults[.pgpKeyURL] != URL(string: controller.pgpKeyURLTextField.text!) ||
                Defaults[.pgpKeyPassphrase] != controller.pgpKeyPassphraseTextField.text! {
                Defaults[.pgpKeyURL] = URL(string: controller.pgpKeyURLTextField.text!)
                Defaults[.pgpKeyPassphrase] = controller.pgpKeyPassphraseTextField.text!
                
                SVProgressHUD.setDefaultMaskType(.black)
                SVProgressHUD.setDefaultStyle(.light)
                SVProgressHUD.show(withStatus: "Fetching PGP Key")
                DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
                    do {
                        try PasswordStore.shared.initPGP(pgpKeyURL: Defaults[.pgpKeyURL]!, pgpKeyLocalPath: Globals.secringPath)
                        DispatchQueue.main.async {
                            self.pgpKeyTableViewCell.detailTextLabel?.text = Defaults[.pgpKeyID]
                            SVProgressHUD.showSuccess(withStatus: "Success. Remember to remove the key from the server.")
                            SVProgressHUD.dismiss(withDelay: 1)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            SVProgressHUD.showError(withStatus: error.localizedDescription)
                            SVProgressHUD.dismiss(withDelay: 1)
                        }
                    }
                }
            }
            
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        touchIDSwitch.onTintColor = UIColor(displayP3Red: 0, green: 122.0/255, blue: 1, alpha: 1)
        touchIDTableViewCell.accessoryView = touchIDSwitch
        touchIDSwitch.addTarget(self, action: #selector(touchIDSwitchAction), for: UIControlEvents.valueChanged)
        if Defaults[.isTouchIDOn] {
            touchIDSwitch.isOn = true
        } else {
            touchIDSwitch.isOn = false
        }
        if PasscodeLockRepository().hasPasscode {
            self.passcodeTableViewCell.detailTextLabel?.text = "On"
        } else {
            self.passcodeTableViewCell.detailTextLabel?.text = "Off"
            touchIDSwitch.isEnabled = false
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.cellForRow(at: indexPath) == passcodeTableViewCell {
            if Defaults[.passcodeKey] != nil{
                showPasscodeActionSheet()
            } else {
                setPasscodeLock()
            }
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if Defaults[.pgpKeyID] == "" {
            pgpKeyTableViewCell.detailTextLabel?.text = "Not Set"
        } else {
            pgpKeyTableViewCell.detailTextLabel?.text = Defaults[.pgpKeyID]
        }
    }
    
    func touchIDSwitchAction(uiSwitch: UISwitch) {
        if uiSwitch.isOn {
            Defaults[.isTouchIDOn] = true
            Globals.passcodeConfiguration.isTouchIDAllowed = true
        } else {
            Defaults[.isTouchIDOn] = false
            Globals.passcodeConfiguration.isTouchIDAllowed = false
        }
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.passcodeLockPresenter = PasscodeLockPresenter(mainWindow: appDelegate.window, configuration: Globals.passcodeConfiguration)
    }
    
    func showPasscodeActionSheet() {
        let passcodeChangeViewController = PasscodeLockViewController(state: .change, configuration: Globals.passcodeConfiguration)
        let passcodeRemoveViewController = PasscodeLockViewController(state: .remove, configuration: Globals.passcodeConfiguration)

        let optionMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let removePasscodeAction = UIAlertAction(title: "Remove Passcode", style: .destructive) { [unowned self] _ in
            passcodeRemoveViewController.successCallback  = { _ in
                self.passcodeTableViewCell.detailTextLabel?.text = "Off"
                self.touchIDSwitch.isEnabled = false
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                appDelegate.passcodeLockPresenter = PasscodeLockPresenter(mainWindow: appDelegate.window, configuration: Globals.passcodeConfiguration)
            }
            self.present(passcodeRemoveViewController, animated: true, completion: nil)
        }
        
        let changePasscodeAction = UIAlertAction(title: "Change Passcode", style: .default) { [unowned self] _ in
            self.present(passcodeChangeViewController, animated: true, completion: nil)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        optionMenu.addAction(removePasscodeAction)
        optionMenu.addAction(changePasscodeAction)
        optionMenu.addAction(cancelAction)
        self.present(optionMenu, animated: true, completion: nil)
    }
    
    func setPasscodeLock() {
        let passcodeSetViewController = PasscodeLockViewController(state: .set, configuration: Globals.passcodeConfiguration)
        passcodeSetViewController.successCallback = { _ in
            self.passcodeTableViewCell.detailTextLabel?.text = "On"
            self.touchIDSwitch.isEnabled = true
        }
        present(passcodeSetViewController, animated: true, completion: nil)
    }
}
