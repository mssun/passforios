//
//  GeneralSettingsTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 9/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import passKit

class GeneralSettingsTableViewController: BasicStaticTableViewController {
    let passwordStore = PasswordStore.shared

    let hideUnknownSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = Colors.systemBlue
        uiSwitch.sizeToFit()
        uiSwitch.addTarget(self, action: #selector(hideUnknownSwitchAction(_:)), for: UIControl.Event.valueChanged)
        return uiSwitch
    }()

    let hideOTPSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = Colors.systemBlue
        uiSwitch.sizeToFit()
        uiSwitch.addTarget(self, action: #selector(hideOTPSwitchAction(_:)), for: UIControl.Event.valueChanged)
        return uiSwitch
    }()

    let rememberPGPPassphraseSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = Colors.systemBlue
        uiSwitch.sizeToFit()
        uiSwitch.addTarget(self, action: #selector(rememberPGPPassphraseSwitchAction(_:)), for: UIControl.Event.valueChanged)
        uiSwitch.isOn = Defaults.isRememberPGPPassphraseOn
        return uiSwitch
    }()

    let rememberGitCredentialPassphraseSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = Colors.systemBlue
        uiSwitch.sizeToFit()
        uiSwitch.addTarget(self, action: #selector(rememberGitCredentialPassphraseSwitchAction(_:)), for: UIControl.Event.valueChanged)
        uiSwitch.isOn = Defaults.isRememberGitCredentialPassphraseOn
        return uiSwitch
    }()

    let showFolderSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = Colors.systemBlue
        uiSwitch.sizeToFit()
        uiSwitch.addTarget(self, action: #selector(showFolderSwitchAction(_:)), for: UIControl.Event.valueChanged)
        uiSwitch.isOn = Defaults.isShowFolderOn
        return uiSwitch
    }()

    let hidePasswordImagesSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = Colors.systemBlue
        uiSwitch.sizeToFit()
        uiSwitch.addTarget(self, action: #selector(hidePasswordImagesSwitchAction(_:)), for: UIControl.Event.valueChanged)
        uiSwitch.isOn = Defaults.isHidePasswordImagesOn
        return uiSwitch
    }()

    override func viewDidLoad() {
        tableData = [
            // section 0
            [[.title: "AboutRepository".localize(), .action: "segue", .link: "showAboutRepositorySegue"],],

            // section 1
            [
                [.title: "PasswordGeneratorFlavor".localize(), .action: "none", .style: CellDataStyle.value1],
            ],

            // section 2
            [
                [.title: "RememberPgpKeyPassphrase".localize(), .action: "none",],
                [.title: "RememberGitCredentialPassphrase".localize(), .action: "none",],
            ],
            [
                [.title: "ShowFolders".localize(), .action: "none",],
                [.title: "HidePasswordImages".localize(), .action: "none",],
                [.title: "HideUnknownFields".localize(), .action: "none",],
                [.title: "HideOtpFields".localize(), .action: "none",],
            ],

        ]
        super.viewDidLoad()

    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell =  super.tableView(tableView, cellForRowAt: indexPath)
        switch cell.textLabel!.text! {
        case "HideUnknownFields".localize():
            cell.accessoryType = .none
            let detailButton = UIButton(type: .detailDisclosure)
            hideUnknownSwitch.frame = CGRect(x: detailButton.bounds.width+10, y: 0, width: hideUnknownSwitch.bounds.width, height: hideUnknownSwitch.bounds.height)
            detailButton.frame = CGRect(x: 0, y: 5, width: detailButton.bounds.width, height: detailButton.bounds.height)
            detailButton.addTarget(self, action: #selector(GeneralSettingsTableViewController.tapHideUnknownSwitchDetailButton(_:)), for: UIControl.Event.touchDown)
            let accessoryView = UIView(frame: CGRect(x: 0, y: 0, width: detailButton.bounds.width + hideUnknownSwitch.bounds.width+10, height: hideUnknownSwitch.bounds.height))
            accessoryView.addSubview(detailButton)
            accessoryView.addSubview(hideUnknownSwitch)
            cell.accessoryView = accessoryView
            cell.selectionStyle = .none
            hideUnknownSwitch.isOn = Defaults.isHideUnknownOn
        case "HideOtpFields".localize():
            cell.accessoryType = .none
            let detailButton = UIButton(type: .detailDisclosure)
            hideOTPSwitch.frame = CGRect(x: detailButton.bounds.width+10, y: 0, width: hideOTPSwitch.bounds.width, height: hideOTPSwitch.bounds.height)
            detailButton.frame = CGRect(x: 0, y: 5, width: detailButton.bounds.width, height: detailButton.bounds.height)
            detailButton.addTarget(self, action: #selector(GeneralSettingsTableViewController.tapHideOTPSwitchDetailButton(_:)), for: UIControl.Event.touchDown)
            let accessoryView = UIView(frame: CGRect(x: 0, y: 0, width: detailButton.bounds.width + hideOTPSwitch.bounds.width+10, height: hideOTPSwitch.bounds.height))
            accessoryView.addSubview(detailButton)
            accessoryView.addSubview(hideOTPSwitch)
            cell.accessoryView = accessoryView
            cell.selectionStyle = .none
            hideOTPSwitch.isOn = Defaults.isHideOTPOn
        case "RememberPgpKeyPassphrase".localize():
            cell.accessoryType = .none
            cell.selectionStyle = .none
            cell.accessoryView = rememberPGPPassphraseSwitch
        case "RememberGitCredentialPassphrase".localize():
            cell.accessoryType = .none
            cell.selectionStyle = .none
            cell.accessoryView = rememberGitCredentialPassphraseSwitch
        case "ShowFolders".localize():
            cell.accessoryType = .none
            cell.selectionStyle = .none
            cell.accessoryView = showFolderSwitch
        case "HidePasswordImages".localize():
            cell.accessoryType = .none
            let detailButton = UIButton(type: .detailDisclosure)
            hidePasswordImagesSwitch.frame = CGRect(x: detailButton.bounds.width+10, y: 0, width: hidePasswordImagesSwitch.bounds.width, height: hidePasswordImagesSwitch.bounds.height)
            detailButton.frame = CGRect(x: 0, y: 5, width: detailButton.bounds.width, height: detailButton.bounds.height)
            detailButton.addTarget(self, action: #selector(GeneralSettingsTableViewController.tapHidePasswordImagesSwitchDetailButton(_:)), for: UIControl.Event.touchDown)
            let accessoryView = UIView(frame: CGRect(x: 0, y: 0, width: detailButton.bounds.width + hidePasswordImagesSwitch.bounds.width+10, height: hidePasswordImagesSwitch.bounds.height))
            accessoryView.addSubview(detailButton)
            accessoryView.addSubview(hidePasswordImagesSwitch)
            cell.accessoryView = accessoryView
            cell.selectionStyle = .none
            hidePasswordImagesSwitch.isOn = Defaults.isHidePasswordImagesOn
        case "PasswordGeneratorFlavor".localize():
            cell.accessoryType = .disclosureIndicator
            cell.detailTextLabel?.text = PasswordGeneratorFlavour.from(Defaults.passwordGeneratorFlavor).name
        default: break
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        super.tableView(tableView, didSelectRowAt: indexPath)
        let cell = tableView.cellForRow(at: indexPath)!
        if cell.textLabel!.text! == "PasswordGeneratorFlavor".localize() {
            tableView.deselectRow(at: indexPath, animated: true)
            showPasswordGeneratorFlavorActionSheet(sourceCell: cell)
        }
    }

    func showPasswordGeneratorFlavorActionSheet(sourceCell: UITableViewCell) {
        let optionMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        var randomFlavorActionTitle = ""
        var appleFlavorActionTitle = ""
        if Defaults.passwordGeneratorFlavor == PasswordGeneratorFlavour.RANDOM.rawValue {
            randomFlavorActionTitle = "✓ " + "RandomString".localize()
            appleFlavorActionTitle = "ApplesKeychainStyle".localize()
        } else {
            randomFlavorActionTitle = "RandomString".localize()
            appleFlavorActionTitle = "✓ " + "ApplesKeychainStyle".localize()
        }
        let randomFlavorAction = UIAlertAction(title: randomFlavorActionTitle, style: .default) { _ in
            Defaults.passwordGeneratorFlavor = PasswordGeneratorFlavour.RANDOM.rawValue
            sourceCell.detailTextLabel?.text = PasswordGeneratorFlavour.RANDOM.name
        }

        let appleFlavorAction = UIAlertAction(title: appleFlavorActionTitle, style: .default) { _ in
            Defaults.passwordGeneratorFlavor = PasswordGeneratorFlavour.APPLE.rawValue
            sourceCell.detailTextLabel?.text = PasswordGeneratorFlavour.APPLE.name
        }

        let cancelAction = UIAlertAction(title: "Cancel".localize(), style: .cancel, handler: nil)
        optionMenu.addAction(randomFlavorAction)
        optionMenu.addAction(appleFlavorAction)
        optionMenu.addAction(cancelAction)
        optionMenu.popoverPresentationController?.sourceView = sourceCell
        optionMenu.popoverPresentationController?.sourceRect = sourceCell.bounds
        self.present(optionMenu, animated: true, completion: nil)
    }

    @objc func tapHideUnknownSwitchDetailButton(_ sender: Any?) {
        let alertMessage = "HideUnknownFieldsExplanation.".localize()
        let alertTitle = "HideUnknownFields".localize()
        Utils.alert(title: alertTitle, message: alertMessage, controller: self, completion: nil)
    }

    @objc func tapHideOTPSwitchDetailButton(_ sender: Any?) {
        let keywordsString = Constants.OTP_KEYWORDS.joined(separator: ", ")
        let alertMessage = "HideOtpFieldsExplanation.".localize(keywordsString)
        let alertTitle = "HideOtpFields".localize()
        Utils.alert(title: alertTitle, message: alertMessage, controller: self, completion: nil)
    }

    @objc func tapHidePasswordImagesSwitchDetailButton(_ sender: Any?) {
        let alertMessage = "HidePasswordImagesExplanation.".localize()
        let alertTitle = "HidePasswordImages".localize()
        Utils.alert(title: alertTitle, message: alertMessage, controller: self, completion: nil)
    }

    @objc func hideUnknownSwitchAction(_ sender: Any?) {
        Defaults.isHideUnknownOn = hideUnknownSwitch.isOn
        NotificationCenter.default.post(name: .passwordDetailDisplaySettingChanged, object: nil)
    }

    @objc func hideOTPSwitchAction(_ sender: Any?) {
        Defaults.isHideOTPOn = hideOTPSwitch.isOn
        NotificationCenter.default.post(name: .passwordDetailDisplaySettingChanged, object: nil)
    }

    @objc func rememberPGPPassphraseSwitchAction(_ sender: Any?) {
        Defaults.isRememberPGPPassphraseOn = rememberPGPPassphraseSwitch.isOn
        if rememberPGPPassphraseSwitch.isOn == false {
            AppKeychain.shared.removeContent(for: Globals.pgpKeyPassphrase)
        }
    }

    @objc func rememberGitCredentialPassphraseSwitchAction(_ sender: Any?) {
        Defaults.isRememberGitCredentialPassphraseOn = rememberGitCredentialPassphraseSwitch.isOn
        if rememberGitCredentialPassphraseSwitch.isOn == false {
            passwordStore.gitSSHPrivateKeyPassphrase = nil
            passwordStore.gitPassword = nil
        }
    }

    @objc func showFolderSwitchAction(_ sender: Any?) {
        Defaults.isShowFolderOn = showFolderSwitch.isOn
        NotificationCenter.default.post(name: .passwordDisplaySettingChanged, object: nil)
    }

    @objc func hidePasswordImagesSwitchAction(_ sender: Any?) {
        Defaults.isHidePasswordImagesOn = hidePasswordImagesSwitch.isOn
        NotificationCenter.default.post(name: .passwordDetailDisplaySettingChanged, object: nil)
    }

}
