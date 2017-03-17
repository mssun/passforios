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
    
    lazy var touchIDSwitch: UISwitch = {
        let uiSwitch = UISwitch(frame: CGRect.zero)
        uiSwitch.onTintColor = Globals.blue
        uiSwitch.addTarget(self, action: #selector(touchIDSwitchAction), for: UIControlEvents.valueChanged)
        return uiSwitch
    }()

    @IBOutlet weak var pgpKeyTableViewCell: UITableViewCell!
    @IBOutlet weak var touchIDTableViewCell: UITableViewCell!
    @IBOutlet weak var passcodeTableViewCell: UITableViewCell!
    @IBOutlet weak var passwordRepositoryTableViewCell: UITableViewCell!
    let passwordStore = PasswordStore.shared

    @IBAction func cancelPGPKey(segue: UIStoryboardSegue) {
    }
    
    @IBAction func savePGPKey(segue: UIStoryboardSegue) {
        if let controller = segue.source as? PGPKeySettingTableViewController {
            Defaults[.pgpPrivateKeyURL] = URL(string: controller.pgpPrivateKeyURLTextField.text!)
            Defaults[.pgpPublicKeyURL] = URL(string: controller.pgpPublicKeyURLTextField.text!)
            self.passwordStore.pgpKeyPassphrase = controller.pgpPassphrase
            Defaults[.pgpKeySource] = "url"
            
            SVProgressHUD.setDefaultMaskType(.black)
            SVProgressHUD.setDefaultStyle(.light)
            SVProgressHUD.show(withStatus: "Fetching PGP Key")
            DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
                do {
                    try self.passwordStore.initPGPKey(from: Defaults[.pgpPublicKeyURL]!, keyType: .public)
                    try self.passwordStore.initPGPKey(from: Defaults[.pgpPrivateKeyURL]!, keyType: .secret)
                    DispatchQueue.main.async {
                        self.pgpKeyTableViewCell.detailTextLabel?.text = self.passwordStore.pgpKeyID
                        SVProgressHUD.showSuccess(withStatus: "Success")
                        SVProgressHUD.dismiss(withDelay: 1)
                        Utils.alert(title: "Rememver to Remove the Key", message: "Remember to remove the key from the server.", controller: self, completion: nil)
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.pgpKeyTableViewCell.detailTextLabel?.text = "Not Set"
                        Utils.alert(title: "Error", message: error.localizedDescription, controller: self, completion: nil)
                    }
                }
            }
            
        } else if let controller = segue.source as? PGPKeyArmorSettingTableViewController {
            Defaults[.pgpKeySource] = "armor"
            self.passwordStore.pgpKeyPassphrase = controller.pgpPassphrase
            if Defaults[.isRememberPassphraseOn] {
                Utils.addPasswordToKeychain(name: "pgpKeyPassphrase", password: controller.pgpPassphrase!)
            }

            Defaults[.pgpPublicKeyArmor] = controller.armorPublicKeyTextView.text!
            Defaults[.pgpPrivateKeyArmor] = controller.armorPrivateKeyTextView.text!
            
            SVProgressHUD.setDefaultMaskType(.black)
            SVProgressHUD.setDefaultStyle(.light)
            SVProgressHUD.show(withStatus: "Fetching PGP Key")
            DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
                do {
                    try self.passwordStore.initPGPKey(with: controller.armorPublicKeyTextView.text, keyType: .public)
                    try self.passwordStore.initPGPKey(with: controller.armorPrivateKeyTextView.text, keyType: .secret)
                    DispatchQueue.main.async {
                        self.pgpKeyTableViewCell.detailTextLabel?.text = self.passwordStore.pgpKeyID
                        SVProgressHUD.showSuccess(withStatus: "Success")
                        SVProgressHUD.dismiss(withDelay: 1)
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.pgpKeyTableViewCell.detailTextLabel?.text = "Not Set"
                        Utils.alert(title: "Error", message: error.localizedDescription, controller: self, completion: nil)
                    }
                }
            }
        }
    }
    
    @IBAction func cancelGitServerSetting(segue: UIStoryboardSegue) {
    }
    
    @IBAction func saveGitServerSetting(segue: UIStoryboardSegue) {
        if let controller = segue.source as? GitServerSettingTableViewController {
            let gitRepostiroyURL = controller.gitRepositoryURLTextField.text!
            let username = controller.usernameTextField.text!
            let password = controller.password
            let auth = controller.authenticationMethod
            
            if Defaults[.gitRepositoryURL] == nil ||
                Defaults[.gitRepositoryURL]!.absoluteString != gitRepostiroyURL ||
                auth != Defaults[.gitRepositoryAuthenticationMethod] ||
                username != Defaults[.gitRepositoryUsername] ||
                password != self.passwordStore.gitRepositoryPassword ||
                self.passwordStore.repositoryExisted() == false {
                
                SVProgressHUD.setDefaultMaskType(.black)
                SVProgressHUD.setDefaultStyle(.light)
                SVProgressHUD.show(withStatus: "Prepare Repository")
                var gitCredential: GitCredential
                if auth == "Password" {
                    gitCredential = GitCredential(credential: GitCredential.Credential.http(userName: username, password: password!))
                } else {
                    gitCredential = GitCredential(
                        credential: GitCredential.Credential.ssh(
                            userName: username,
                            password: Utils.getPasswordFromKeychain(name: "gitRepositorySSHPrivateKeyPassphrase") ?? "",
                            publicKeyFile: Globals.sshPublicKeyURL,
                            privateKeyFile: Globals.sshPrivateKeyURL,
                            passwordNotSetCallback: self.requestSshKeyPassword
                        )
                    )
                }
                let dispatchQueue = DispatchQueue.global(qos: .userInitiated)
                dispatchQueue.async {
                    do {
                        try self.passwordStore.cloneRepository(remoteRepoURL: URL(string: gitRepostiroyURL)!,
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
                            self.passwordStore.updatePasswordEntityCoreData()
                            Defaults[.lastUpdatedTime] = Date()
                            NotificationCenter.default.post(Notification(name: Notification.Name("passwordUpdated")))
                            Defaults[.gitRepositoryURL] = URL(string: gitRepostiroyURL)
                            Defaults[.gitRepositoryUsername] = username
                            Defaults[.gitRepositoryAuthenticationMethod] = auth
                            Defaults[.gitRepositoryPasswordAttempts] = 0
                            self.passwordRepositoryTableViewCell.detailTextLabel?.text = Defaults[.gitRepositoryURL]?.host
                            SVProgressHUD.showSuccess(withStatus: "Done")
                            SVProgressHUD.dismiss(withDelay: 1)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            Utils.alert(title: "Error", message: error.localizedDescription, controller: self, completion: nil)
                        }
                    }
                    
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsTableViewController.actOnPasswordStoreErasedNotification), name: NSNotification.Name(rawValue: "passwordStoreErased"), object: nil)
        self.passwordRepositoryTableViewCell.detailTextLabel?.text = Defaults[.gitRepositoryURL]?.host
        touchIDTableViewCell.accessoryView = touchIDSwitch
        setPGPKeyTableViewCellDetailText()
        setPasswordRepositoryTableViewCellDetailText()
        setTouchIDSwitch()
        setPasscodeLockRepositoryTableViewCellDetailText()
    }
    
    private func setPasscodeLockRepositoryTableViewCellDetailText() {
        if PasscodeLockRepository().hasPasscode {
            self.passcodeTableViewCell.detailTextLabel?.text = "On"
        } else {
            self.passcodeTableViewCell.detailTextLabel?.text = "Off"
            touchIDSwitch.isEnabled = false
            Globals.passcodeConfiguration.isTouchIDAllowed = false
        }
    }
    
    private func setPGPKeyTableViewCellDetailText() {
        if let pgpKeyID = self.passwordStore.pgpKeyID {
            pgpKeyTableViewCell.detailTextLabel?.text = pgpKeyID
        } else {
            pgpKeyTableViewCell.detailTextLabel?.text = "Not Set"
        }
    }
    
    private func setPasswordRepositoryTableViewCellDetailText() {
        if Defaults[.gitRepositoryURL] == nil {
            passwordRepositoryTableViewCell.detailTextLabel?.text = "Not Set"
        } else {
            passwordRepositoryTableViewCell.detailTextLabel?.text = Defaults[.gitRepositoryURL]!.host
        }
    }
    
    private func setTouchIDSwitch() {
        if Defaults[.isTouchIDOn] {
            touchIDSwitch.isOn = true
        } else {
            touchIDSwitch.isOn = false
        }
    }

    func requestSshKeyPassword() -> String {
        let sem = DispatchSemaphore(value: 0)
        var newPassword = ""

        DispatchQueue.main.async {
            SVProgressHUD.dismiss()
            let alert = UIAlertController(title: "Password", message: "Please fill in the password of your SSH key.", preferredStyle: UIAlertControllerStyle.alert)

            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {_ in
                newPassword = alert.textFields!.first!.text!
                sem.signal()
            }))

            alert.addTextField(configurationHandler: {(textField: UITextField!) in
                textField.text = self.passwordStore.gitRepositoryPassword
                textField.isSecureTextEntry = true
            })

            self.present(alert, animated: true, completion: nil)
        }

        let _ = sem.wait(timeout: DispatchTime.distantFuture)
        return newPassword
    }

    func actOnPasswordStoreErasedNotification() {
        setPGPKeyTableViewCellDetailText()
        setPasswordRepositoryTableViewCellDetailText()
        setTouchIDSwitch()
        setPasscodeLockRepositoryTableViewCellDetailText()

        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.passcodeLockPresenter = PasscodeLockPresenter(mainWindow: appDelegate.window, configuration: Globals.passcodeConfiguration)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.cellForRow(at: indexPath) == passcodeTableViewCell {
            if Defaults[.passcodeKey] != nil{
                showPasscodeActionSheet()
            } else {
                setPasscodeLock()
            }
        } else if tableView.cellForRow(at: indexPath) == pgpKeyTableViewCell {
            showPGPKeyActionSheet()
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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

    func pgpKeyExists() -> Bool {
        return FileManager.default.fileExists(atPath: Globals.pgpPublicKeyPath) &&
        FileManager.default.fileExists(atPath: Globals.pgpPrivateKeyPath)
    }
    
    func showPGPKeyActionSheet() {
        let optionMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        var urlActionTitle = "Download from URL"
        var armorActionTitle = "ASCII-Armor Encrypted Key"
        var fileActionTitle = "Use Uploaded Keys"
        
        if Defaults[.pgpKeySource] == "url" {
           urlActionTitle = "✓ \(urlActionTitle)"
        } else if Defaults[.pgpKeySource] == "armor" {
            armorActionTitle = "✓ \(armorActionTitle)"
        } else if Defaults[.pgpKeySource] == "file" {
            fileActionTitle = "✓ \(fileActionTitle)"
        }
        let urlAction = UIAlertAction(title: urlActionTitle, style: .default) { _ in
            self.performSegue(withIdentifier: "setPGPKeyByURLSegue", sender: self)
        }
        let armorAction = UIAlertAction(title: armorActionTitle, style: .default) { _ in
            self.performSegue(withIdentifier: "setPGPKeyByASCIISegue", sender: self)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        optionMenu.addAction(urlAction)
        optionMenu.addAction(armorAction)

        if (pgpKeyExists()) {
            let fileAction = UIAlertAction(title: fileActionTitle, style: .default) { _ in

                SVProgressHUD.setDefaultMaskType(.black)
                SVProgressHUD.setDefaultStyle(.light)
                SVProgressHUD.show(withStatus: "Reading PGP key")

                let alert = UIAlertController(
                    title: "PGP Passphrase",
                    message: "Please fill in the passphrase for your PGP key.",
                    preferredStyle: UIAlertControllerStyle.alert
                )

                alert.addAction(
                    UIAlertAction(
                        title: "OK",
                        style: UIAlertActionStyle.default,
                        handler: {_ in
                            Utils.addPasswordToKeychain(
                                name: "pgpKeyPassphrase",
                                password: alert.textFields!.first!.text!
                            )
                        }
                    )
                )

                alert.addTextField(
                   configurationHandler: {(textField: UITextField!) in
                            textField.text = Utils.getPasswordFromKeychain(name: "pgpKeyPassphrase") ?? ""
                            textField.isSecureTextEntry = true
                    }
                )


                DispatchQueue.main.async {
                    self.passwordStore.initPGPKeys()

                    let key: PGPKey = self.passwordStore.getPgpPrivateKey()
                    Defaults[.pgpKeySource] = "file"

                    if (key.isEncrypted) {
                        SVProgressHUD.dismiss()
                        self.present(alert, animated: true, completion: nil)
                    }

                    SVProgressHUD.dismiss()
                    self.pgpKeyTableViewCell.detailTextLabel?.text = self.passwordStore.pgpKeyID
                }

            }

            optionMenu.addAction(fileAction)
        }
        
        if Defaults[.pgpKeySource] != nil {
            let deleteAction = UIAlertAction(title: "Remove PGP Keys", style: .destructive) { _ in
                Utils.removePGPKeys()
                self.pgpKeyTableViewCell.detailTextLabel?.text = "Not Set"
            }
            optionMenu.addAction(deleteAction)
        }
        optionMenu.addAction(cancelAction)
        optionMenu.popoverPresentationController?.sourceView = pgpKeyTableViewCell
        optionMenu.popoverPresentationController?.sourceRect = pgpKeyTableViewCell.bounds
        self.present(optionMenu, animated: true, completion: nil)
    }
    
    func showPasscodeActionSheet() {
        let passcodeChangeViewController = PasscodeLockViewController(state: .change, configuration: Globals.passcodeConfiguration)
        let passcodeRemoveViewController = PasscodeLockViewController(state: .remove, configuration: Globals.passcodeConfiguration)

        let optionMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let removePasscodeAction = UIAlertAction(title: "Remove Passcode", style: .destructive) { [weak self] _ in
            passcodeRemoveViewController.successCallback  = { _ in
                self?.passcodeTableViewCell.detailTextLabel?.text = "Off"
                self?.touchIDSwitch.isEnabled = false
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                appDelegate.passcodeLockPresenter = PasscodeLockPresenter(mainWindow: appDelegate.window, configuration: Globals.passcodeConfiguration)
            }
            self?.present(passcodeRemoveViewController, animated: true, completion: nil)
        }
        
        let changePasscodeAction = UIAlertAction(title: "Change Passcode", style: .default) { [weak self] _ in
            self?.present(passcodeChangeViewController, animated: true, completion: nil)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        optionMenu.addAction(removePasscodeAction)
        optionMenu.addAction(changePasscodeAction)
        optionMenu.addAction(cancelAction)
        optionMenu.popoverPresentationController?.sourceView = passcodeTableViewCell
        optionMenu.popoverPresentationController?.sourceRect = passcodeTableViewCell.bounds
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
