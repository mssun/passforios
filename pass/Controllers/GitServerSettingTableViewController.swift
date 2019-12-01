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
    @IBOutlet weak var gitURLCell: UITableViewCell!
    @IBOutlet weak var gitRepositoryURLTabelViewCell: UITableViewCell!

    private let passwordStore = PasswordStore.shared
    private var sshLabel: UILabel? = nil

    private var gitAuthenticationMethod: GitAuthenticationMethod {
        get { SharedDefaults[.gitAuthenticationMethod] }
        set {
            SharedDefaults[.gitAuthenticationMethod] = newValue
            updateAuthenticationMethodCheckView(for: newValue)
        }
    }
    private var gitUrl: URL {
        get { SharedDefaults[.gitURL] }
        set { SharedDefaults[.gitURL] = newValue }
    }
    private var gitBranchName: String {
        get { SharedDefaults[.gitBranchName] }
        set { SharedDefaults[.gitBranchName] = newValue }
    }
    private var gitUsername: String {
        get { SharedDefaults[.gitUsername] }
        set { SharedDefaults[.gitUsername] = newValue }
    }
    private var gitCredential: GitCredential {
        get {
            switch SharedDefaults[.gitAuthenticationMethod] {
            case .password:
                return GitCredential(credential: .http(userName: SharedDefaults[.gitUsername]))
            case .key:
                let privateKey: String = AppKeychain.shared.get(for: SshKey.PRIVATE.getKeychainKey()) ?? ""
                return GitCredential(credential: .ssh(userName: SharedDefaults[.gitUsername], privateKey: privateKey))
            }
        }
    }

    private func updateAuthenticationMethodCheckView(for method: GitAuthenticationMethod) {
        let passwordCheckView = authPasswordCell.viewWithTag(1001)!
        let sshKeyCheckView = authSSHKeyCell.viewWithTag(1001)!

        switch method {
        case .password:
            passwordCheckView.isHidden = false
            sshKeyCheckView.isHidden = true
        case .key:
            passwordCheckView.isHidden = true
            sshKeyCheckView.isHidden = false
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Grey out ssh option if ssh_key is not present
        sshLabel?.isEnabled = AppKeychain.shared.contains(key: SshKey.PRIVATE.getKeychainKey())
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        gitURLTextField.text = self.gitUrl.absoluteString
        usernameTextField.text = self.gitUsername
        branchNameTextField.text = self.gitBranchName
        sshLabel = authSSHKeyCell.subviews[0].subviews[0] as? UILabel
        updateAuthenticationMethodCheckView(for: .password)
        authSSHKeyCell.accessoryType = .detailButton
    }

    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        if cell == authSSHKeyCell {
            showSSHKeyActionSheet()
        } else if cell == gitURLCell {
            showGitURLFormatHelp()
        }
    }

    private func showGitURLFormatHelp() {
        Utils.alert(title: "Git URL Format", message: "https://example.com[:port]/project.git\nssh://[user@]server[:port]/project.git\n[user@]server:project.git (no scheme)", controller: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
    }

    private func cloneAndSegueIfSuccess() {
        // Remember git credential password/passphrase temporarily, ask whether users want this after a successful clone.
        SharedDefaults[.isRememberGitCredentialPassphraseOn] = true
        DispatchQueue.global(qos: .userInitiated).async() {
            do {
                let transferProgressBlock: (UnsafePointer<git_transfer_progress>, UnsafeMutablePointer<ObjCBool>) -> Void = { (git_transfer_progress, _) in
                    let progress = Float(git_transfer_progress.pointee.received_objects) / Float(git_transfer_progress.pointee.total_objects)
                    SVProgressHUD.showProgress(progress, status: "Cloning Remote Repository")
                }

                let checkoutProgressBlock: (String?, UInt, UInt) -> Void = { (_, completedSteps, totalSteps) in
                    let progress = Float(completedSteps) / Float(totalSteps)
                    SVProgressHUD.showProgress(progress, status: "CheckingOutBranch".localize(self.gitBranchName))
                }

                try self.passwordStore.cloneRepository(remoteRepoURL: self.gitUrl,
                                                       credential: self.gitCredential,
                                                       branchName: self.gitBranchName,
                                                       requestGitPassword: self.requestGitPassword,
                                                       transferProgressBlock: transferProgressBlock,
                                                       checkoutProgressBlock: checkoutProgressBlock)

                SVProgressHUD.dismiss() {
                    let savePassphraseAlert: UIAlertController = {
                        let alert = UIAlertController(title: "Done".localize(), message: "WantToSaveGitCredential?".localize(), preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "No".localize(), style: .default) { _ in
                            SharedDefaults[.isRememberGitCredentialPassphraseOn] = false
                            self.passwordStore.gitPassword = nil
                            self.passwordStore.gitSSHPrivateKeyPassphrase = nil
                            self.performSegue(withIdentifier: "saveGitServerSettingSegue", sender: self)
                        })
                        alert.addAction(UIAlertAction(title: "Yes".localize(), style: .destructive) {_ in
                            SharedDefaults[.isRememberGitCredentialPassphraseOn] = true
                            self.performSegue(withIdentifier: "saveGitServerSettingSegue", sender: self)
                        })
                        return alert
                    }()
                    self.present(savePassphraseAlert, animated: true, completion: nil)
                }
            } catch {
                SVProgressHUD.dismiss()
                let error = error as NSError
                var message = error.localizedDescription
                if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                    message = "\(message)\n\("UnderlyingError".localize(underlyingError.localizedDescription))"
                }
                Utils.alert(title: "Error".localize(), message: message, controller: self, completion: nil)
            }
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        if cell == authPasswordCell {
            self.gitAuthenticationMethod = .password
        } else if cell == authSSHKeyCell {
            if !AppKeychain.shared.contains(key: SshKey.PRIVATE.getKeychainKey()) {
                Utils.alert(title: "CannotSelectSshKey".localize(), message: "PleaseSetupSshKeyFirst.".localize(), controller: self, completion: nil)
                gitAuthenticationMethod = .password
            } else {
                gitAuthenticationMethod = .key
            }
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    @IBAction func save(_ sender: Any) {
        guard let gitURLTextFieldText = gitURLTextField.text, let gitURL = URL(string: gitURLTextFieldText.trimmed) else {
            Utils.alert(title: "CannotSave".localize(), message: "SetGitRepositoryUrl".localize(), controller: self, completion: nil)
            return
        }

        guard let branchName = branchNameTextField.text, !branchName.trimmed.isEmpty else {
            Utils.alert(title: "CannotSave".localize(), message: "SpecifyBranchName.".localize(), controller: self, completion: nil)
            return
        }

        if let scheme = gitURL.scheme {
            switch scheme {
            case "ssh", "http", "https":
                if gitURL.user == nil && usernameTextField.text == nil {
                    Utils.alert(title: "CannotSave".localize(), message: "CannotFindUsername.".localize(), controller: self, completion: nil)
                    return
                }
                if let urlUsername = gitURL.user, let textFieldUsername = usernameTextField.text, urlUsername != textFieldUsername.trimmed {
                    Utils.alert(title: "CannotSave".localize(), message: "CheckEnteredUsername.".localize(), controller: self, completion: nil)
                    return
                }
            case "file": break
            default:
                Utils.alert(title: "CannotSave".localize(), message: "Protocol is not supported", controller: self, completion: nil)
                return
            }
        }

        self.gitUrl = gitURL
        self.gitBranchName = branchName.trimmed
        self.gitUsername = (gitURL.user ?? usernameTextField.text ?? "git").trimmed

        if passwordStore.repositoryExisted() {
            let overwriteAlert: UIAlertController = {
                let alert = UIAlertController(title: "Overwrite?".localize(), message: "OperationWillOverwriteData.".localize(), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Overwrite".localize(), style: .destructive) { _ in
                    self.cloneAndSegueIfSuccess()
                })
                alert.addAction(UIAlertAction(title: "Cancel".localize(), style: .cancel, handler: nil))
                return alert
            }()
            self.present(overwriteAlert, animated: true, completion: nil)
        } else {
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

        if KeyFileManager.PrivateSsh.doesKeyFileExist() {
            // might keys updated via iTunes, or downloaded/pasted inside the app
            fileActionTitle.append(" (\("Import".localize()))")
            let fileAction = UIAlertAction(title: fileActionTitle, style: .default) { _ in
                do {
                    try self.passwordStore.gitSSHKeyImportFromFileSharing()
                    SharedDefaults[.gitSSHKeySource] = "file"
                    SVProgressHUD.showSuccess(withStatus: "Imported".localize())
                    SVProgressHUD.dismiss(withDelay: 1)
                    self.sshLabel?.isEnabled = true
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
                self.sshLabel?.isEnabled = false
                self.updateAuthenticationMethodCheckView(for: .password)
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
        let message: String = {
            switch credential {
            case .http:
                return "FillInGitAccountPassword.".localize()
            case .ssh:
                return "FillInSshKeyPassphrase.".localize()
            }
        }()

        DispatchQueue.main.async {
            SVProgressHUD.dismiss()
            let alert = UIAlertController(title: "Password".localize(), message: message, preferredStyle: .alert)
            alert.addTextField(configurationHandler: {(textField: UITextField!) in
                textField.text = lastPassword ?? ""
                textField.isSecureTextEntry = true
            })
            alert.addAction(UIAlertAction(title: "Ok".localize(), style: .default, handler: {_ in
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
