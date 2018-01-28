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
import passKit

class SettingsTableViewController: UITableViewController, UITabBarControllerDelegate {
    @IBOutlet weak var pgpKeyTableViewCell: UITableViewCell!
    @IBOutlet weak var passcodeTableViewCell: UITableViewCell!
    @IBOutlet weak var passwordRepositoryTableViewCell: UITableViewCell!
    var setPasscodeLockAlert: UIAlertController?
    
    let passwordStore = PasswordStore.shared
    var passcodeLock = PasscodeLock.shared
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func savePGPKey(segue: UIStoryboardSegue) {
        if let controller = segue.source as? PGPKeySettingTableViewController {
            SharedDefaults[.pgpPrivateKeyURL] = URL(string: controller.pgpPrivateKeyURLTextField.text!)
            SharedDefaults[.pgpPublicKeyURL] = URL(string: controller.pgpPublicKeyURLTextField.text!)
            if SharedDefaults[.isRememberPGPPassphraseOn] {
                self.passwordStore.pgpKeyPassphrase = controller.pgpPassphrase
            }
            SharedDefaults[.pgpKeySource] = "url"
            
            SVProgressHUD.setDefaultMaskType(.black)
            SVProgressHUD.setDefaultStyle(.light)
            SVProgressHUD.show(withStatus: "Fetching PGP Key")
            DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
                do {
                    try self.passwordStore.initPGPKey(from: SharedDefaults[.pgpPublicKeyURL]!, keyType: .public)
                    try self.passwordStore.initPGPKey(from: SharedDefaults[.pgpPrivateKeyURL]!, keyType: .secret)
                    DispatchQueue.main.async {
                        self.pgpKeyTableViewCell.detailTextLabel?.text = self.passwordStore.pgpKeyID
                        SVProgressHUD.showSuccess(withStatus: "Success")
                        SVProgressHUD.dismiss(withDelay: 1)
                        Utils.alert(title: "Remember to Remove the Key", message: "Remember to remove the key from the server.", controller: self, completion: nil)
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.pgpKeyTableViewCell.detailTextLabel?.text = "Not Set"
                        Utils.alert(title: "Error", message: error.localizedDescription, controller: self, completion: nil)
                    }
                }
            }
            
        } else if let controller = segue.source as? PGPKeyArmorSettingTableViewController {
            SharedDefaults[.pgpKeySource] = "armor"
            if SharedDefaults[.isRememberPGPPassphraseOn] {
                self.passwordStore.pgpKeyPassphrase = controller.pgpPassphrase
            }

            SharedDefaults[.pgpPublicKeyArmor] = controller.armorPublicKeyTextView.text!
            SharedDefaults[.pgpPrivateKeyArmor] = controller.armorPrivateKeyTextView.text!
            
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
    
    private func saveImportedPGPKey() {
        // load keys
        SharedDefaults[.pgpKeySource] = "file"
        SVProgressHUD.setDefaultMaskType(.black)
        SVProgressHUD.setDefaultStyle(.light)
        SVProgressHUD.show(withStatus: "Fetching PGP Key")
        passwordStore.pgpKeyImportFromFileSharing()
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            do {
                try self.passwordStore.initPGPKeys()
                DispatchQueue.main.async {
                    self.pgpKeyTableViewCell.detailTextLabel?.text = self.passwordStore.pgpKeyID
                    SVProgressHUD.showSuccess(withStatus: "Imported")
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
    
    @IBAction func saveGitServerSetting(segue: UIStoryboardSegue) {
        self.passwordRepositoryTableViewCell.detailTextLabel?.text = SharedDefaults[.gitURL]?.host
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return super.tableView(tableView, numberOfRowsInSection: section)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsTableViewController.actOnPasswordStoreErasedNotification), name: .passwordStoreErased, object: nil)
        self.passwordRepositoryTableViewCell.detailTextLabel?.text = SharedDefaults[.gitURL]?.host
        setPGPKeyTableViewCellDetailText()
        setPasswordRepositoryTableViewCellDetailText()
        setPasscodeLockCell()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        tabBarController!.delegate = self
    }
    
    private func setPasscodeLockCell() {
        if passcodeLock.hasPasscode {
            self.passcodeTableViewCell.detailTextLabel?.text = "On"
        } else {
            self.passcodeTableViewCell.detailTextLabel?.text = "Off"
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
        if SharedDefaults[.gitURL] == nil {
            passwordRepositoryTableViewCell.detailTextLabel?.text = "Not Set"
        } else {
            passwordRepositoryTableViewCell.detailTextLabel?.text = SharedDefaults[.gitURL]!.host
        }
    }
    
    @objc func actOnPasswordStoreErasedNotification() {
        setPGPKeyTableViewCellDetailText()
        setPasswordRepositoryTableViewCellDetailText()
        setPasscodeLockCell()

        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.passcodeLockPresenter = PasscodeLockPresenter(mainWindow: appDelegate.window)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.cellForRow(at: indexPath) == passcodeTableViewCell {
            if SharedDefaults[.passcodeKey] != nil{
                showPasscodeActionSheet()
            } else {
                setPasscodeLock()
            }
        } else if tableView.cellForRow(at: indexPath) == pgpKeyTableViewCell {
            showPGPKeyActionSheet()
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
   
    func showPGPKeyActionSheet() {
        let optionMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        var urlActionTitle = "Download from URL"
        var armorActionTitle = "ASCII-Armor Encrypted Key"
        var fileActionTitle = "iTunes File Sharing"
        
        if SharedDefaults[.pgpKeySource] == "url" {
           urlActionTitle = "✓ \(urlActionTitle)"
        } else if SharedDefaults[.pgpKeySource] == "armor" {
            armorActionTitle = "✓ \(armorActionTitle)"
        } else if SharedDefaults[.pgpKeySource] == "file" {
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

        if passwordStore.pgpKeyExists(inFileSharing: true) {
            fileActionTitle.append(" (Import)")
            let fileAction = UIAlertAction(title: fileActionTitle, style: .default) { _ in
                // passphrase related
                let savePassphraseAlert = UIAlertController(title: "Passphrase", message: "Do you want to save the passphrase for later decryption?", preferredStyle: UIAlertControllerStyle.alert)
                // no
                savePassphraseAlert.addAction(UIAlertAction(title: "No", style: UIAlertActionStyle.default) { _ in
                    self.passwordStore.pgpKeyPassphrase = nil
                    SharedDefaults[.isRememberPGPPassphraseOn] = false
                    self.saveImportedPGPKey()
                })
                // yes
                savePassphraseAlert.addAction(UIAlertAction(title: "Yes", style: UIAlertActionStyle.destructive) {_ in
                    // ask for the passphrase
                    let alert = UIAlertController(title: "Passphrase", message: "Please fill in the passphrase of your PGP secret key.", preferredStyle: UIAlertControllerStyle.alert)
                    alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {_ in
                        self.passwordStore.pgpKeyPassphrase = alert.textFields?.first?.text
                        SharedDefaults[.isRememberPGPPassphraseOn] = true
                        self.saveImportedPGPKey()
                    }))
                    alert.addTextField(configurationHandler: {(textField: UITextField!) in
                        textField.text = ""
                        textField.isSecureTextEntry = true
                    })
                    self.present(alert, animated: true, completion: nil)
                })
                self.present(savePassphraseAlert, animated: true, completion: nil)
            }
            optionMenu.addAction(fileAction)
        } else {
            fileActionTitle.append(" (Tips)")
            let fileAction = UIAlertAction(title: fileActionTitle, style: .default) { _ in
                let title = "Tips"
                let message = "Copy your public and private keys to Pass with names \"gpg_key.pub\" and \"gpg_key\" (without quotes) via iTunes. Then come back and click \"iTunes File Sharing\" to finish."
                Utils.alert(title: title, message: message, controller: self)
            }
            optionMenu.addAction(fileAction)
        }
        
        
        if SharedDefaults[.pgpKeySource] != nil {
            let deleteAction = UIAlertAction(title: "Remove PGP Keys", style: .destructive) { _ in
                self.passwordStore.removePGPKeys()
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
        let optionMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let passcodeRemoveViewController = PasscodeLockViewController()
        
        
        let removePasscodeAction = UIAlertAction(title: "Remove Passcode", style: .destructive) { [weak self] _ in
            passcodeRemoveViewController.successCallback  = {
                self?.passcodeLock.delete()
                self?.setPasscodeLockCell()
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                appDelegate.passcodeLockPresenter = PasscodeLockPresenter(mainWindow: appDelegate.window)
            }
            self?.present(passcodeRemoveViewController, animated: true, completion: nil)
        }
        
        let changePasscodeAction = UIAlertAction(title: "Change Passcode", style: .default) { [weak self] _ in
            self?.setPasscodeLock()
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        optionMenu.addAction(removePasscodeAction)
        optionMenu.addAction(changePasscodeAction)
        optionMenu.addAction(cancelAction)
        optionMenu.popoverPresentationController?.sourceView = passcodeTableViewCell
        optionMenu.popoverPresentationController?.sourceRect = passcodeTableViewCell.bounds
        self.present(optionMenu, animated: true, completion: nil)
    }

    @objc func alertTextFieldDidChange(_ sender: UITextField) {
        // check whether we should enable the Save button in setPasscodeLockAlert
        if let setPasscodeLockAlert = self.setPasscodeLockAlert,
            let setPasscodeLockAlertTextFields0 = setPasscodeLockAlert.textFields?[0],
            let setPasscodeLockAlertTextFields1 = setPasscodeLockAlert.textFields?[1] {
            if sender == setPasscodeLockAlertTextFields0 || sender == setPasscodeLockAlertTextFields1 {
                // two passwords should be the same, and length >= 4
                let passcodeText = setPasscodeLockAlertTextFields0.text!
                let passcodeConfirmationText = setPasscodeLockAlertTextFields1.text!
                setPasscodeLockAlert.actions[0].isEnabled = passcodeText == passcodeConfirmationText && passcodeText.count >= 4
            }
        }
    }
    
    func setPasscodeLock() {
        // prepare the alert for setting the passcode
        setPasscodeLockAlert = UIAlertController(title: "Set passcode", message: "Fill in your passcode for Pass (at least 4 characters)", preferredStyle: .alert)
        setPasscodeLockAlert?.addTextField(configurationHandler: {(_ textField: UITextField) -> Void in
            textField.placeholder = "Password"
            textField.isSecureTextEntry = true
            textField.addTarget(self, action: #selector(self.alertTextFieldDidChange(_:)), for: UIControlEvents.editingChanged)
        })
        setPasscodeLockAlert?.addTextField(configurationHandler: {(_ textField: UITextField) -> Void in
            textField.placeholder = "Password Confirmation"
            textField.isSecureTextEntry = true
            textField.addTarget(self, action: #selector(self.alertTextFieldDidChange(_:)), for: UIControlEvents.editingChanged)
        })
        
        // save action
        let saveAction = UIAlertAction(title: "Save", style: .default) { (action:UIAlertAction) -> Void in
            let passcode: String = self.setPasscodeLockAlert!.textFields![0].text!
            self.passcodeLock.save(passcode: passcode)
            // refresh the passcode lock cell ("On")
            self.setPasscodeLockCell()
        }
        saveAction.isEnabled = false  // disable the Save button by default
        
        // cancel action
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        // present
        setPasscodeLockAlert?.addAction(saveAction)
        setPasscodeLockAlert?.addAction(cancelAction)
        self.present(setPasscodeLockAlert!, animated: true, completion: nil)
    }
}
