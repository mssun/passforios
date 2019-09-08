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
    let keychain = AppKeychain.shared
    var passcodeLock = PasscodeLock.shared

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction func savePGPKey(segue: UIStoryboardSegue) {
        if let controller = segue.source as? PGPKeySettingTableViewController {
            SharedDefaults[.pgpPrivateKeyURL] = URL(string: controller.pgpPrivateKeyURLTextField.text!.trimmed)
            SharedDefaults[.pgpPublicKeyURL] = URL(string: controller.pgpPublicKeyURLTextField.text!.trimmed)
            SharedDefaults[.pgpKeySource] = "url"

            SVProgressHUD.setDefaultMaskType(.black)
            SVProgressHUD.setDefaultStyle(.light)
            SVProgressHUD.show(withStatus: "FetchingPgpKey".localize())
            DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
                do {
                    try KeyFileManager.PublicPgp.importKey(from: SharedDefaults[.pgpPublicKeyURL]!)
                    try KeyFileManager.PrivatePgp.importKey(from: SharedDefaults[.pgpPrivateKeyURL]!)
                    try PGPAgent.shared.initKeys()
                    DispatchQueue.main.async {
                        self.pgpKeyTableViewCell.detailTextLabel?.text = PGPAgent.shared.keyId
                        SVProgressHUD.showSuccess(withStatus: "Success".localize())
                        SVProgressHUD.dismiss(withDelay: 1)
                        Utils.alert(title: "RememberToRemoveKey".localize(), message: "RememberToRemoveKeyFromServer.".localize(), controller: self, completion: nil)
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.pgpKeyTableViewCell.detailTextLabel?.text = "NotSet".localize()
                        Utils.alert(title: "Error".localize(), message: error.localizedDescription, controller: self, completion: nil)
                    }
                }
            }

        } else if let controller = segue.source as? PGPKeyArmorSettingTableViewController {
            SharedDefaults[.pgpKeySource] = "armor"

            SVProgressHUD.setDefaultMaskType(.black)
            SVProgressHUD.setDefaultStyle(.light)
            SVProgressHUD.show(withStatus: "FetchingPgpKey".localize())
            DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
                do {
                    try KeyFileManager.PublicPgp.importKey(from: controller.armorPublicKeyTextView.text ?? "")
                    try KeyFileManager.PrivatePgp.importKey(from: controller.armorPrivateKeyTextView.text ?? "")
                    try PGPAgent.shared.initKeys()
                    DispatchQueue.main.async {
                        self.pgpKeyTableViewCell.detailTextLabel?.text = PGPAgent.shared.keyId
                        SVProgressHUD.showSuccess(withStatus: "Success".localize())
                        SVProgressHUD.dismiss(withDelay: 1)
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.pgpKeyTableViewCell.detailTextLabel?.text = "NotSet".localize()
                        Utils.alert(title: "Error".localize(), message: error.localizedDescription, controller: self, completion: nil)
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
        SVProgressHUD.show(withStatus: "FetchingPgpKey".localize())
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            do {
                try KeyFileManager.PublicPgp.importKeyFromFileSharing()
                try KeyFileManager.PrivatePgp.importKeyFromFileSharing()
                try PGPAgent.shared.initKeys()
                DispatchQueue.main.async {
                    self.pgpKeyTableViewCell.detailTextLabel?.text = PGPAgent.shared.keyId
                    SVProgressHUD.showSuccess(withStatus: "Imported".localize())
                    SVProgressHUD.dismiss(withDelay: 1)
                }
            } catch {
                DispatchQueue.main.async {
                    self.pgpKeyTableViewCell.detailTextLabel?.text = "NotSet".localize()
                    Utils.alert(title: "Error".localize(), message: error.localizedDescription, controller: self, completion: nil)
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
            self.passcodeTableViewCell.detailTextLabel?.text = "On".localize()
        } else {
            self.passcodeTableViewCell.detailTextLabel?.text = "Off".localize()
        }
    }

    private func setPGPKeyTableViewCellDetailText() {
        try? PGPAgent.shared.initKeys()
        pgpKeyTableViewCell.detailTextLabel?.text = PGPAgent.shared.keyId ?? "NotSet".localize()
    }

    private func setPasswordRepositoryTableViewCellDetailText() {
        if SharedDefaults[.gitURL] == nil {
            passwordRepositoryTableViewCell.detailTextLabel?.text = "NotSet".localize()
        } else {
            passwordRepositoryTableViewCell.detailTextLabel?.text = SharedDefaults[.gitURL]!.host
        }
    }

    @objc func actOnPasswordStoreErasedNotification() {
        setPGPKeyTableViewCellDetailText()
        setPasswordRepositoryTableViewCellDetailText()
        setPasscodeLockCell()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.cellForRow(at: indexPath) == passcodeTableViewCell {
            if passcodeLock.hasPasscode {
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
        var urlActionTitle = "DownloadFromUrl".localize()
        var armorActionTitle = "AsciiArmorEncryptedKey".localize()
        var fileActionTitle = "ITunesFileSharing".localize()

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
        let cancelAction = UIAlertAction(title: "Cancel".localize(), style: .cancel, handler: nil)
        optionMenu.addAction(urlAction)
        optionMenu.addAction(armorAction)

        if KeyFileManager.PublicPgp.doesKeyFileExist() && KeyFileManager.PrivatePgp.doesKeyFileExist() {
            fileActionTitle.append(" (\("Import".localize()))")
            let fileAction = UIAlertAction(title: fileActionTitle, style: .default) { _ in
                // passphrase related
                let savePassphraseAlert = UIAlertController(title: "Passphrase".localize(), message: "WantToSavePassphrase?".localize(), preferredStyle: UIAlertController.Style.alert)
                // no
                savePassphraseAlert.addAction(UIAlertAction(title: "No".localize(), style: UIAlertAction.Style.default) { _ in
                    self.keychain.removeContent(for: Globals.pgpKeyPassphrase)
                    SharedDefaults[.isRememberPGPPassphraseOn] = false
                    self.saveImportedPGPKey()
                })
                // yes
                savePassphraseAlert.addAction(UIAlertAction(title: "Yes".localize(), style: UIAlertAction.Style.destructive) {_ in
                    // ask for the passphrase
                    let alert = UIAlertController(title: "Passphrase".localize(), message: "FillInPgpPassphrase.".localize(), preferredStyle: UIAlertController.Style.alert)
                    alert.addAction(UIAlertAction(title: "Ok".localize(), style: UIAlertAction.Style.default, handler: {_ in
                        self.keychain.add(string: alert.textFields?.first?.text, for: Globals.pgpKeyPassphrase)
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
            fileActionTitle.append(" (\("Tips".localize()))")
            let fileAction = UIAlertAction(title: fileActionTitle, style: .default) { _ in
                let title = "Tips".localize()
                let message = "PgpCopyPublicAndPrivateKeyToPass.".localize()
                Utils.alert(title: title, message: message, controller: self)
            }
            optionMenu.addAction(fileAction)
        }


        if SharedDefaults[.pgpKeySource] != nil {
            let deleteAction = UIAlertAction(title: "RemovePgpKeys".localize(), style: .destructive) { _ in
                self.keychain.removeContent(for: PgpKey.PUBLIC.getKeychainKey())
                self.keychain.removeContent(for: PgpKey.PRIVATE.getKeychainKey())
                PGPAgent.shared.uninitKeys()
                self.pgpKeyTableViewCell.detailTextLabel?.text = "NotSet".localize()
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


        let removePasscodeAction = UIAlertAction(title: "RemovePasscode".localize(), style: .destructive) { [weak self] _ in
            passcodeRemoveViewController.successCallback  = {
                self?.passcodeLock.delete()
                self?.setPasscodeLockCell()
            }
            self?.present(passcodeRemoveViewController, animated: true, completion: nil)
        }

        let changePasscodeAction = UIAlertAction(title: "ChangePasscode".localize(), style: .default) { [weak self] _ in
            self?.setPasscodeLock()
        }

        let cancelAction = UIAlertAction(title: "Cancel".localize(), style: .cancel, handler: nil)
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
        setPasscodeLockAlert = UIAlertController(title: "SetPasscode".localize(), message: "FillInAppPasscode.".localize(), preferredStyle: .alert)
        setPasscodeLockAlert?.addTextField(configurationHandler: {(_ textField: UITextField) -> Void in
            textField.placeholder = "Passcode".localize()
            textField.isSecureTextEntry = true
            textField.addTarget(self, action: #selector(self.alertTextFieldDidChange(_:)), for: UIControl.Event.editingChanged)
        })
        setPasscodeLockAlert?.addTextField(configurationHandler: {(_ textField: UITextField) -> Void in
            textField.placeholder = "PasswordConfirmation".localize()
            textField.isSecureTextEntry = true
            textField.addTarget(self, action: #selector(self.alertTextFieldDidChange(_:)), for: UIControl.Event.editingChanged)
        })

        // save action
        let saveAction = UIAlertAction(title: "Save".localize(), style: .default) { (action:UIAlertAction) -> Void in
            let passcode: String = self.setPasscodeLockAlert!.textFields![0].text!
            self.passcodeLock.save(passcode: passcode)
            // refresh the passcode lock cell ("On")
            self.setPasscodeLockCell()
        }
        saveAction.isEnabled = false  // disable the Save button by default

        // cancel action
        let cancelAction = UIAlertAction(title: "Cancel".localize(), style: .cancel, handler: nil)

        // present
        setPasscodeLockAlert?.addAction(saveAction)
        setPasscodeLockAlert?.addAction(cancelAction)
        self.present(setPasscodeLockAlert!, animated: true, completion: nil)
    }
}
