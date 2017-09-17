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
import PasscodeLock
import LocalAuthentication
import passKit

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
    var passcodeLockConfig = PasscodeLockConfiguration.shared
    
    @IBAction func savePGPKey(segue: UIStoryboardSegue) {
        if let controller = segue.source as? PGPKeySettingTableViewController {
            SharedDefaults[.pgpPrivateKeyURL] = URL(string: controller.pgpPrivateKeyURLTextField.text!)
            SharedDefaults[.pgpPublicKeyURL] = URL(string: controller.pgpPublicKeyURLTextField.text!)
            if SharedDefaults[.isRememberPassphraseOn] {
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
            if SharedDefaults[.isRememberPassphraseOn] {
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
        // Security section, hide TouchID if the device doesn't support
        if section == 1 {
            if hasTouchID() {
                return 2
            } else {
                return 1
            }
        }
        return super.tableView(tableView, numberOfRowsInSection: section)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsTableViewController.actOnPasswordStoreErasedNotification), name: .passwordStoreErased, object: nil)
        self.passwordRepositoryTableViewCell.detailTextLabel?.text = SharedDefaults[.gitURL]?.host
        touchIDTableViewCell.accessoryView = touchIDSwitch
        setPGPKeyTableViewCellDetailText()
        setPasswordRepositoryTableViewCellDetailText()
        setPasscodeLockTouchIDCells()
    }
    
    private func hasTouchID() -> Bool {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(LAPolicy.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            return true
        } else {
            switch error!.code {
            case LAError.Code.touchIDNotEnrolled.rawValue:
                return true
            case LAError.Code.passcodeNotSet.rawValue:
                return true
            default:
                return false
            }
        }
    }
    
    private func isTouchIDEnabled() -> Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }
    
    private func setPasscodeLockTouchIDCells() {
        if PasscodeLockConfiguration.shared.repository.hasPasscode {
            self.passcodeTableViewCell.detailTextLabel?.text = "On"
            passcodeLockConfig.isTouchIDAllowed = SharedDefaults[.isTouchIDOn]
            touchIDSwitch.isOn = SharedDefaults[.isTouchIDOn]
        } else {
            self.passcodeTableViewCell.detailTextLabel?.text = "Off"
            SharedDefaults[.isTouchIDOn] = false
            passcodeLockConfig.isTouchIDAllowed = SharedDefaults[.isTouchIDOn]
            touchIDSwitch.isOn = SharedDefaults[.isTouchIDOn]
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
    
    func actOnPasswordStoreErasedNotification() {
        setPGPKeyTableViewCellDetailText()
        setPasswordRepositoryTableViewCellDetailText()
        setPasscodeLockTouchIDCells()

        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.passcodeLockPresenter = PasscodeLockPresenter(mainWindow: appDelegate.window, configuration: passcodeLockConfig)
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
    
    func touchIDSwitchAction(uiSwitch: UISwitch) {
        if !PasscodeLockConfiguration.shared.repository.hasPasscode || !isTouchIDEnabled() {
            // switch off
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                uiSwitch.isOn = SharedDefaults[.isTouchIDOn]  // SharedDefaults[.isTouchIDOn] should be false
                Utils.alert(title: "Notice", message: "Please enable Touch ID of your phone and setup the passcode lock for Pass.", controller: self, completion: nil)
            }
        } else {
            SharedDefaults[.isTouchIDOn] = uiSwitch.isOn
            passcodeLockConfig.isTouchIDAllowed = SharedDefaults[.isTouchIDOn]
        }
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.passcodeLockPresenter = PasscodeLockPresenter(mainWindow: appDelegate.window, configuration: passcodeLockConfig)
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
                    SharedDefaults[.isRememberPassphraseOn] = false
                    self.saveImportedPGPKey()
                })
                // yes
                savePassphraseAlert.addAction(UIAlertAction(title: "Yes", style: UIAlertActionStyle.destructive) {_ in
                    // ask for the passphrase
                    let alert = UIAlertController(title: "Passphrase", message: "Please fill in the passphrase of your PGP secret key.", preferredStyle: UIAlertControllerStyle.alert)
                    alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {_ in
                        self.passwordStore.pgpKeyPassphrase = alert.textFields?.first?.text
                        SharedDefaults[.isRememberPassphraseOn] = true
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
        let passcodeChangeViewController = PasscodeLockViewController(state: .change, configuration: passcodeLockConfig)
        let passcodeRemoveViewController = PasscodeLockViewController(state: .remove, configuration: passcodeLockConfig)

        let optionMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let removePasscodeAction = UIAlertAction(title: "Remove Passcode", style: .destructive) { [weak self] _ in
            passcodeRemoveViewController.successCallback  = { _ in
                self?.setPasscodeLockTouchIDCells()
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                appDelegate.passcodeLockPresenter = PasscodeLockPresenter(mainWindow: appDelegate.window, configuration: (self?.passcodeLockConfig)!)
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
        let passcodeSetViewController = PasscodeLockViewController(state: .set, configuration: passcodeLockConfig)
        passcodeSetViewController.successCallback = { _ in
            self.setPasscodeLockTouchIDCells()
        }
        present(passcodeSetViewController, animated: true, completion: nil)
    }
}
