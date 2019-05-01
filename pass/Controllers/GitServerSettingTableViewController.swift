//
//  GitServerSettingTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 21/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import SVProgressHUD
import passKit

class GitServerSettingTableViewController: UITableViewController {

    @IBOutlet weak var gitURLTextField: UITextField!
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var branchNameTextField: UITextField!
    @IBOutlet weak var authSSHKeyCell: UITableViewCell!
    @IBOutlet weak var authPasswordCell: UITableViewCell!
    let passwordStore = PasswordStore.shared
    var sshLabel: UILabel? = nil

    var authenticationMethod = SharedDefaults[.gitAuthenticationMethod] ?? "Password"

    private func checkAuthenticationMethod(method: String) {
        let passwordCheckView = authPasswordCell.viewWithTag(1001)!
        let sshKeyCheckView = authSSHKeyCell.viewWithTag(1001)!

        switch method {
        case "Password":
            passwordCheckView.isHidden = false
            sshKeyCheckView.isHidden = true
        case "SSH Key":
            passwordCheckView.isHidden = true
            sshKeyCheckView.isHidden = false
        default:
            passwordCheckView.isHidden = false
            sshKeyCheckView.isHidden = true
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Grey out ssh option if ssh_key is not present
        if let sshLabel = sshLabel {
            sshLabel.isEnabled = passwordStore.gitSSHKeyExists()
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        if let url = SharedDefaults[.gitURL] {
            gitURLTextField.text = url.absoluteString
        }
        usernameTextField.text = SharedDefaults[.gitUsername]
        branchNameTextField.text = SharedDefaults[.gitBranchName]
        sshLabel = authSSHKeyCell.subviews[0].subviews[0] as? UILabel
        checkAuthenticationMethod(method: authenticationMethod)
        authSSHKeyCell.accessoryType = .detailButton
    }

    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        if cell == authSSHKeyCell {
            showSSHKeyActionSheet()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
    }

    private func cloneAndSegueIfSuccess() {
        // try to clone
        let gitRepostiroyURL = gitURLTextField.text!.trimmed
        let username = usernameTextField.text!
        let branchName = branchNameTextField.text!
        let auth = authenticationMethod

        SVProgressHUD.setDefaultMaskType(.black)
        SVProgressHUD.setDefaultStyle(.light)
        SVProgressHUD.show(withStatus: "PrepareRepository".localize())
        var gitCredential: GitCredential
        if auth == "Password" {
            gitCredential = GitCredential(credential: GitCredential.Credential.http(userName: username))
        } else {
            gitCredential = GitCredential(
                credential: GitCredential.Credential.ssh(
                    userName: username,
                    privateKeyFile: Globals.gitSSHPrivateKeyURL
                )
            )
        }
        // Remember git credential password/passphrase temporarily, ask whether users want this after a successful clone.
        SharedDefaults[.isRememberGitCredentialPassphraseOn] = true
        let dispatchQueue = DispatchQueue.global(qos: .userInitiated)
        dispatchQueue.async {
            do {
                try self.passwordStore.cloneRepository(remoteRepoURL: URL(string: gitRepostiroyURL)!,
                                                       credential: gitCredential,
                                                       branchName: branchName,
                                                       requestGitPassword: self.requestGitPassword,
                                                       transferProgressBlock: { (git_transfer_progress, stop) in
                                                        DispatchQueue.main.async {
                                                            SVProgressHUD.showProgress(Float(git_transfer_progress.pointee.received_objects)/Float(git_transfer_progress.pointee.total_objects), status: "Clone Remote Repository")
                                                        }
                },
                                                       checkoutProgressBlock: { (path, completedSteps, totalSteps) in
                                                        DispatchQueue.main.async {
                                                            SVProgressHUD.showProgress(Float(completedSteps)/Float(totalSteps), status: "CheckingOutBranch".localize(branchName))
                                                        }
                })
                DispatchQueue.main.async {
                    SharedDefaults[.gitURL] = URL(string: gitRepostiroyURL)
                    SharedDefaults[.gitUsername] = username
                    SharedDefaults[.gitBranchName] = branchName
                    SharedDefaults[.gitAuthenticationMethod] = auth
                    SVProgressHUD.dismiss()
                    let savePassphraseAlert = UIAlertController(title: "Done".localize(), message: "WantToSaveGitCredential?".localize(), preferredStyle: UIAlertController.Style.alert)
                    // no
                    savePassphraseAlert.addAction(UIAlertAction(title: "No".localize(), style: UIAlertAction.Style.default) { _ in
                        SharedDefaults[.isRememberGitCredentialPassphraseOn] = false
                        self.passwordStore.gitPassword = nil
                        self.passwordStore.gitSSHPrivateKeyPassphrase = nil
                        self.performSegue(withIdentifier: "saveGitServerSettingSegue", sender: self)
                    })
                    // yes
                    savePassphraseAlert.addAction(UIAlertAction(title: "Yes".localize(), style: UIAlertAction.Style.destructive) {_ in
                        SharedDefaults[.isRememberGitCredentialPassphraseOn] = true
                        self.performSegue(withIdentifier: "saveGitServerSettingSegue", sender: self)
                    })
                    self.present(savePassphraseAlert, animated: true, completion: nil)
                }
            } catch {
                DispatchQueue.main.async {
                    let error = error as NSError
                    var message = error.localizedDescription
                    if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                        message = "\(message)\n\("UnderlyingError".localize()): \(underlyingError.localizedDescription)"
                    }
                    Utils.alert(title: "Error".localize(), message: message, controller: self, completion: nil)
                }
            }
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        if cell == authPasswordCell {
            authenticationMethod = "Password"
        } else if cell == authSSHKeyCell {

            if !passwordStore.gitSSHKeyExists() {
                Utils.alert(title: "CannotSelectSshKey".localize(), message: "PleaseSetupSshKeyFirst.".localize(), controller: self, completion: nil)
                authenticationMethod = "Password"
            } else {
                authenticationMethod = "SSH Key"
            }
        }
        checkAuthenticationMethod(method: authenticationMethod)
        tableView.deselectRow(at: indexPath, animated: true)
    }

    @IBAction func save(_ sender: Any) {

        // some sanity checks
        guard let gitURL = URL(string: gitURLTextField.text!) else {
            Utils.alert(title: "CannotSave".localize(), message: "SetGitRepositoryUrl".localize(), controller: self, completion: nil)
            return
        }

        switch gitURL.scheme {
        case let val where val == "https":
            break
        case let val where val == "ssh":
            guard let sshUsername = gitURL.user, sshUsername.isEmpty == false else {
                Utils.alert(title: "CannotSave".localize(), message: "CannotFindUsername.".localize(), controller: self, completion: nil)
                return
            }
            guard let username = usernameTextField.text, username == sshUsername else {
                Utils.alert(title: "CannotSave".localize(), message: "CheckEnteredUsername.".localize(), controller: self, completion: nil)
                return
            }
        case let val where val == "http":
            Utils.alert(title: "CannotSave".localize(), message: "UseHttps.".localize(), controller: self, completion: nil)
            return
        default:
            Utils.alert(title: "CannotSave".localize(), message: "SpecifySchema.".localize(), controller: self, completion: nil)
            return
        }

        if passwordStore.repositoryExisted() {
            let alert = UIAlertController(title: "Overwrite?".localize(), message: "OperationWillOverwriteData.".localize(), preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "Overwrite".localize(), style: UIAlertAction.Style.destructive, handler: { _ in
                // perform segue only after a successful clone
                self.cloneAndSegueIfSuccess()
            }))
            alert.addAction(UIAlertAction(title: "Cancel".localize(), style: UIAlertAction.Style.cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        } else {
            // perform segue only after a successful clone
            cloneAndSegueIfSuccess()
        }
    }

    func showSSHKeyActionSheet() {
        let optionMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        var urlActionTitle = "DownloadFromUrl".localize()
        var armorActionTitle = "AsciiArmorEncryptedKey".localize()
        var fileActionTitle = "ITunesFileSharing".localize()

        if SharedDefaults[.gitSSHKeySource] == "url" {
            urlActionTitle = "✓ \(urlActionTitle)"
        } else if SharedDefaults[.gitSSHKeySource] == "armor" {
            armorActionTitle = "✓ \(armorActionTitle)"
        } else if SharedDefaults[.gitSSHKeySource] == "file" {
            fileActionTitle = "✓ \(fileActionTitle)"
        }
        let urlAction = UIAlertAction(title: urlActionTitle, style: .default) { _ in
            self.performSegue(withIdentifier: "setGitSSHKeyByURLSegue", sender: self)
        }
        let armorAction = UIAlertAction(title: armorActionTitle, style: .default) { _ in
            self.performSegue(withIdentifier: "setGitSSHKeyByArmorSegue", sender: self)
        }
        let cancelAction = UIAlertAction(title: "Cancel".localize(), style: .cancel, handler: nil)
        optionMenu.addAction(urlAction)
        optionMenu.addAction(armorAction)

        if passwordStore.gitSSHKeyExists(inFileSharing: true) {
            // might keys updated via iTunes, or downloaded/pasted inside the app
            fileActionTitle.append(" (\("Import".localize()))")
            let fileAction = UIAlertAction(title: fileActionTitle, style: .default) { _ in
                do {
                    try self.passwordStore.gitSSHKeyImportFromFileSharing()
                    SharedDefaults[.gitSSHKeySource] = "file"
                    SVProgressHUD.showSuccess(withStatus: "Imported".localize())
                    SVProgressHUD.dismiss(withDelay: 1)
                } catch {
                    Utils.alert(title: "Error".localize(), message: error.localizedDescription, controller: self, completion: nil)
                }
            }
            optionMenu.addAction(fileAction)
        } else {
            fileActionTitle.append(" (\("Tips".localize()))")
            let fileAction = UIAlertAction(title: fileActionTitle, style: .default) { _ in
                let title = "Tips".localize()
                let message = "SshCopyPrivateKeyToPass.".localize()
                Utils.alert(title: title, message: message, controller: self)
            }
            optionMenu.addAction(fileAction)
        }

        if SharedDefaults[.gitSSHKeySource] != nil {
            let deleteAction = UIAlertAction(title: "RemoveSShKeys".localize(), style: .destructive) { _ in
                self.passwordStore.removeGitSSHKeys()
                SharedDefaults[.gitSSHKeySource] = nil
                if let sshLabel = self.sshLabel {
                    sshLabel.isEnabled = false
                    self.checkAuthenticationMethod(method: "Password".localize())
                }
            }
            optionMenu.addAction(deleteAction)
        }
        optionMenu.addAction(cancelAction)
        optionMenu.popoverPresentationController?.sourceView = authSSHKeyCell
        optionMenu.popoverPresentationController?.sourceRect = authSSHKeyCell.bounds
        self.present(optionMenu, animated: true, completion: nil)
    }

    private func requestGitPassword(credential: GitCredential.Credential, lastPassword: String?) -> String? {
        let sem = DispatchSemaphore(value: 0)
        var password: String?
        var message = ""
        switch credential {
        case .http:
            message = "FillInGitAccountPassword.".localize()
        case .ssh:
            message = "FillInSshKeyPassphrase.".localize()
        }

        DispatchQueue.main.async {
            SVProgressHUD.dismiss()
            let alert = UIAlertController(title: "Password".localize(), message: message, preferredStyle: UIAlertController.Style.alert)
            alert.addTextField(configurationHandler: {(textField: UITextField!) in
                textField.text = lastPassword ?? ""
                textField.isSecureTextEntry = true
            })
            alert.addAction(UIAlertAction(title: "Ok".localize(), style: UIAlertAction.Style.default, handler: {_ in
                password = alert.textFields!.first!.text
                sem.signal()
            }))
            alert.addAction(UIAlertAction(title: "Cancel".localize(), style: .cancel) { _ in
                password = nil
                sem.signal()
            })
            self.present(alert, animated: true, completion: nil)
        }

        let _ = sem.wait(timeout: .distantFuture)
        return password
    }
}
