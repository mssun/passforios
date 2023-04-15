//
//  AdvancedSettingsTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 7/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import AuthenticationServices
import passKit
import SVProgressHUD
import UIKit

class AdvancedSettingsTableViewController: UITableViewController {
    @IBOutlet var encryptInASCIIArmoredTableViewCell: UITableViewCell!
    @IBOutlet var gitSignatureTableViewCell: UITableViewCell!
    @IBOutlet var eraseDataTableViewCell: UITableViewCell!
    @IBOutlet var discardChangesTableViewCell: UITableViewCell!
    @IBOutlet var clearSuggestionsTableViewCell: UITableViewCell!
    let passwordStore = PasswordStore.shared

    private lazy var encryptInASCIIArmoredSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = Colors.systemBlue
        uiSwitch.sizeToFit()
        uiSwitch.addTarget(self, action: #selector(encryptInASCIIArmoredAction), for: UIControl.Event.valueChanged)
        return uiSwitch
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        encryptInASCIIArmoredSwitch.isOn = Defaults.encryptInArmored
        encryptInASCIIArmoredTableViewCell.accessoryView = encryptInASCIIArmoredSwitch
        encryptInASCIIArmoredTableViewCell.selectionStyle = .none
        setGitSignatureText()
    }

    private func setGitSignatureText() {
        let gitSignatureName = passwordStore.gitSignatureForNow?.name ?? ""
        let gitSignatureEmail = passwordStore.gitSignatureForNow?.email ?? ""
        gitSignatureTableViewCell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .footnote)
        gitSignatureTableViewCell.detailTextLabel?.text = "\(gitSignatureName) <\(gitSignatureEmail)>"
        if Defaults.gitSignatureName == nil, Defaults.gitSignatureEmail == nil {
            gitSignatureTableViewCell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .body)
            gitSignatureTableViewCell.detailTextLabel?.text = "NotSet".localize()
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if tableView.cellForRow(at: indexPath) == eraseDataTableViewCell {
            let alert = UIAlertController(title: "ErasePasswordStoreData?".localize(), message: "EraseExplanation.".localize(), preferredStyle: UIAlertController.Style.alert)
            alert.addAction(
                UIAlertAction(title: "ErasePasswordStoreData".localize(), style: UIAlertAction.Style.destructive) { [unowned self] _ in
                    SVProgressHUD.show(withStatus: "Erasing...".localize())
                    passwordStore.erase()
                    navigationController!.popViewController(animated: true)
                    SVProgressHUD.showSuccess(withStatus: "Done".localize())
                    SVProgressHUD.dismiss(withDelay: 1)
                }
            )
            alert.addAction(UIAlertAction.dismiss())
            present(alert, animated: true, completion: nil)
        } else if tableView.cellForRow(at: indexPath) == discardChangesTableViewCell {
            let alert = UIAlertController(title: "DiscardAllLocalChanges?".localize(), message: "DiscardExplanation.".localize(), preferredStyle: UIAlertController.Style.alert)
            alert.addAction(
                UIAlertAction(title: "DiscardAllLocalChanges".localize(), style: UIAlertAction.Style.destructive) { [unowned self] _ in
                    SVProgressHUD.show(withStatus: "Resetting...".localize())
                    do {
                        let numberDiscarded = try passwordStore.reset()
                        navigationController!.popViewController(animated: true)
                        SVProgressHUD.showSuccess(withStatus: "DiscardedCommits(%d)".localize(numberDiscarded))
                        SVProgressHUD.dismiss(withDelay: 1)
                    } catch {
                        Utils.alert(title: "Error".localize(), message: error.localizedDescription, controller: self, completion: nil)
                    }
                }
            )
            alert.addAction(UIAlertAction.dismiss())
            present(alert, animated: true, completion: nil)
        } else if tableView.cellForRow(at: indexPath) == clearSuggestionsTableViewCell {
            ASCredentialIdentityStore.shared.removeAllCredentialIdentities { _, error in
                if let error {
                    SVProgressHUD.showError(withStatus: "FailedToClearQuickTypeSuggestions".localize(error))
                    SVProgressHUD.dismiss(withDelay: 1)
                } else {
                    SVProgressHUD.showSuccess(withStatus: "Done".localize())
                    SVProgressHUD.dismiss(withDelay: 1)
                }
            }
        }
    }

    override func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    override func tableView(_: UITableView, estimatedHeightForRowAt _: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    @objc
    func encryptInASCIIArmoredAction(_: Any?) {
        Defaults.encryptInArmored = encryptInASCIIArmoredSwitch.isOn
    }

    @IBAction
    private func saveGitConfigSetting(segue: UIStoryboardSegue) {
        if let controller = segue.source as? GitConfigSettingsTableViewController {
            if let gitSignatureName = controller.nameTextField.text,
               let gitSignatureEmail = controller.emailTextField.text {
                Defaults.gitSignatureName = gitSignatureName.isEmpty ? nil : gitSignatureName
                Defaults.gitSignatureEmail = gitSignatureEmail.isEmpty ? nil : gitSignatureEmail
            }
            setGitSignatureText()
        }
    }
}
