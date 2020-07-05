//
//  SettingsTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 18/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import CoreData
import passKit
import SVProgressHUD
import UIKit

class SettingsTableViewController: UITableViewController, UITabBarControllerDelegate {
    @IBOutlet var pgpKeyTableViewCell: UITableViewCell!
    @IBOutlet var passcodeTableViewCell: UITableViewCell!
    @IBOutlet var passwordRepositoryTableViewCell: UITableViewCell!
    var setPasscodeLockAlert: UIAlertController?

    let passwordStore = PasswordStore.shared
    let keychain = AppKeychain.shared
    var passcodeLock = PasscodeLock.shared

    func tabBarController(_: UITabBarController, didSelect _: UIViewController) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction
    private func savePGPKey(segue: UIStoryboardSegue) {
        guard let sourceController = segue.source as? PGPKeyImporter, sourceController.isReadyToUse() else {
            return
        }
        savePGPKey(using: sourceController)
    }

    private func savePGPKey(using keyImporter: PGPKeyImporter) {
        SVProgressHUD.setDefaultMaskType(.black)
        SVProgressHUD.setDefaultStyle(.light)
        SVProgressHUD.show(withStatus: "FetchingPgpKey".localize())
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            Defaults.pgpKeySource = type(of: keyImporter).keySource
            do {
                // Remove exiting passphrase
                AppKeychain.shared.removeAllContent(withPrefix: Globals.pgpKeyPassphrase)
                try keyImporter.importKeys()
                try PGPAgent.shared.initKeys()
                DispatchQueue.main.async {
                    self.setPGPKeyTableViewCellDetailText()
                    SVProgressHUD.showSuccess(withStatus: "Success".localize())
                    SVProgressHUD.dismiss(withDelay: 1)
                    keyImporter.doAfterImport()
                }
            } catch {
                DispatchQueue.main.async {
                    self.pgpKeyTableViewCell.detailTextLabel?.text = "NotSet".localize()
                    Utils.alert(title: "Error".localize(), message: error.localizedDescription, controller: self, completion: nil)
                }
            }
        }
    }

    @IBAction
    private func saveGitServerSetting(segue _: UIStoryboardSegue) {
        passwordRepositoryTableViewCell.detailTextLabel?.text = Defaults.gitURL.host
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsTableViewController.actOnPasswordStoreErasedNotification), name: .passwordStoreErased, object: nil)
        passwordRepositoryTableViewCell.detailTextLabel?.text = Defaults.gitURL.host
        setPGPKeyTableViewCellDetailText()
        setPasscodeLockCell()
    }

    override func viewWillAppear(_: Bool) {
        super.viewWillAppear(true)
        tabBarController!.delegate = self
        setPasswordRepositoryTableViewCellDetailText()
    }

    private func setPasscodeLockCell() {
        if passcodeLock.hasPasscode {
            passcodeTableViewCell.detailTextLabel?.text = "On".localize()
        } else {
            passcodeTableViewCell.detailTextLabel?.text = "Off".localize()
        }
    }

    private func setPGPKeyTableViewCellDetailText() {
        var label = "NotSet".localize()
        let keyID = (try? PGPAgent.shared.getShortKeyID()) ?? []
        if keyID.count == 1 {
            label = keyID.first ?? ""
        } else if keyID.count > 1 {
            label = "Multiple"
        }
        pgpKeyTableViewCell.detailTextLabel?.text = label
    }

    private func setPasswordRepositoryTableViewCellDetailText() {
        let host: String? = {
            let gitURL = Defaults.gitURL
            if gitURL.scheme == nil {
                return URL(string: "scheme://" + gitURL.absoluteString)?.host
            } else {
                return gitURL.host
            }
        }()
        passwordRepositoryTableViewCell.detailTextLabel?.text = host
    }

    @objc
    func actOnPasswordStoreErasedNotification() {
        setPGPKeyTableViewCellDetailText()
        setPasswordRepositoryTableViewCellDetailText()
        setPasscodeLockCell()
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        cell.textLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        cell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        cell.textLabel?.adjustsFontForContentSizeCategory = true
        cell.detailTextLabel?.adjustsFontForContentSizeCategory = true
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)

        if cell == passcodeTableViewCell {
            if passcodeLock.hasPasscode {
                showPasscodeActionSheet()
            } else {
                setPasscodeLock()
            }
        } else if cell == pgpKeyTableViewCell {
            showPGPKeyActionSheet()
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func showPGPKeyActionSheet() {
        let optionMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        optionMenu.addAction(
            UIAlertAction(title: PGPKeyUrlImportTableViewController.menuLabel, style: .default) { _ in
                self.performSegue(withIdentifier: "setPGPKeyByURLSegue", sender: self)
            }
        )
        optionMenu.addAction(
            UIAlertAction(title: PGPKeyArmorImportTableViewController.menuLabel, style: .default) { _ in
                self.performSegue(withIdentifier: "setPGPKeyByASCIISegue", sender: self)
            }
        )
        optionMenu.addAction(
            UIAlertAction(title: PGPKeyFileImportTableViewController.menuLabel, style: .default) { _ in
                self.performSegue(withIdentifier: "setPGPKeyByFileSegue", sender: self)
            }
        )

        if isReadyToUse() {
            optionMenu.addAction(
                UIAlertAction(title: "\(Self.menuLabel) (\("Import".localize()))", style: .default) { _ in
                    self.saveImportedKeys()
                }
            )
        } else {
            optionMenu.addAction(
                UIAlertAction(title: "\(Self.menuLabel) (\("Tips".localize()))", style: .default) { _ in
                    let title = "Tips".localize()
                    let message = "PgpCopyPublicAndPrivateKeyToPass.".localize()
                    Utils.alert(title: title, message: message, controller: self)
                }
            )
        }

        if Defaults.pgpKeySource != nil {
            optionMenu.addAction(
                UIAlertAction(title: "RemovePgpKeys".localize(), style: .destructive) { _ in
                    self.keychain.removeContent(for: PgpKey.PUBLIC.getKeychainKey())
                    self.keychain.removeContent(for: PgpKey.PRIVATE.getKeychainKey())
                    PGPAgent.shared.uninitKeys()
                    self.pgpKeyTableViewCell.detailTextLabel?.text = "NotSet".localize()
                    Defaults.pgpKeySource = nil
                }
            )
        }
        optionMenu.addAction(UIAlertAction.cancel())
        optionMenu.popoverPresentationController?.sourceView = pgpKeyTableViewCell
        optionMenu.popoverPresentationController?.sourceRect = pgpKeyTableViewCell.bounds
        present(optionMenu, animated: true)
    }

    func showPasscodeActionSheet() {
        let optionMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let passcodeRemoveViewController = PasscodeLockViewController()

        let removePasscodeAction = UIAlertAction(title: "RemovePasscode".localize(), style: .destructive) { [weak self] _ in
            passcodeRemoveViewController.successCallback = {
                self?.passcodeLock.delete()
                self?.setPasscodeLockCell()
            }
            self?.present(passcodeRemoveViewController, animated: true, completion: nil)
        }

        let changePasscodeAction = UIAlertAction(title: "ChangePasscode".localize(), style: .default) { [weak self] _ in
            self?.setPasscodeLock()
        }

        optionMenu.addAction(removePasscodeAction)
        optionMenu.addAction(changePasscodeAction)
        optionMenu.addAction(UIAlertAction.cancel())
        optionMenu.popoverPresentationController?.sourceView = passcodeTableViewCell
        optionMenu.popoverPresentationController?.sourceRect = passcodeTableViewCell.bounds
        present(optionMenu, animated: true, completion: nil)
    }

    @objc
    func alertTextFieldDidChange(_ sender: UITextField) {
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
        setPasscodeLockAlert?.addTextField { textField -> Void in
            textField.placeholder = "Passcode".localize()
            textField.isSecureTextEntry = true
            textField.addTarget(self, action: #selector(self.alertTextFieldDidChange(_:)), for: UIControl.Event.editingChanged)
        }
        setPasscodeLockAlert?.addTextField { textField -> Void in
            textField.placeholder = "PasswordConfirmation".localize()
            textField.isSecureTextEntry = true
            textField.addTarget(self, action: #selector(self.alertTextFieldDidChange(_:)), for: UIControl.Event.editingChanged)
        }

        // save action
        let saveAction = UIAlertAction(title: "Save".localize(), style: .default) { (_: UIAlertAction) -> Void in
            let passcode: String = self.setPasscodeLockAlert!.textFields![0].text!
            self.passcodeLock.save(passcode: passcode)
            // refresh the passcode lock cell ("On")
            self.setPasscodeLockCell()
        }
        saveAction.isEnabled = false // disable the Save button by default

        // cancel action
        let cancelAction = UIAlertAction.cancel()

        // present
        setPasscodeLockAlert?.addAction(saveAction)
        setPasscodeLockAlert?.addAction(cancelAction)
        present(setPasscodeLockAlert!, animated: true, completion: nil)
    }
}

extension SettingsTableViewController: PGPKeyImporter {
    static let keySource = KeySource.itunes
    static let label = "ITunesFileSharing".localize()

    func isReadyToUse() -> Bool {
        KeyFileManager.PublicPgp.doesKeyFileExist() && KeyFileManager.PrivatePgp.doesKeyFileExist()
    }

    func importKeys() throws {
        try KeyFileManager.PublicPgp.importKeyFromFileSharing()
        try KeyFileManager.PrivatePgp.importKeyFromFileSharing()
    }

    func saveImportedKeys() {
        savePGPKey(using: self)
    }
}
