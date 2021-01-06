//
//  GeneralSettingsTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 9/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import passKit
import UIKit

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
            [[.title: "AboutRepository".localize(), .action: "segue", .link: "showAboutRepositorySegue"]],

            // section 1
            [
                [.title: "RememberPgpKeyPassphrase".localize(), .action: "none"],
                [.title: "RememberGitCredentialPassphrase".localize(), .action: "none"],
            ],

            // section 2
            [
                [.title: "ShowFolders".localize(), .action: "none"],
                [.title: "HidePasswordImages".localize(), .action: "none"],
                [.title: "HideUnknownFields".localize(), .action: "none"],
                [.title: "HideOtpFields".localize(), .action: "none"],
            ],
        ]
        super.viewDidLoad()
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        switch cell.textLabel!.text! {
        case "HideUnknownFields".localize():
            cell.accessoryType = .none
            let detailButton = UIButton(type: .detailDisclosure)
            hideUnknownSwitch.frame = CGRect(x: detailButton.bounds.width + 10, y: 0, width: hideUnknownSwitch.bounds.width, height: hideUnknownSwitch.bounds.height)
            detailButton.frame = CGRect(x: 0, y: 5, width: detailButton.bounds.width, height: detailButton.bounds.height)
            detailButton.addTarget(self, action: #selector(GeneralSettingsTableViewController.tapHideUnknownSwitchDetailButton(_:)), for: UIControl.Event.touchDown)
            let accessoryView = UIView(frame: CGRect(x: 0, y: 0, width: detailButton.bounds.width + hideUnknownSwitch.bounds.width + 10, height: cell.contentView.bounds.height))
            accessoryView.addSubview(detailButton)
            accessoryView.addSubview(hideUnknownSwitch)
            hideUnknownSwitch.center.y = accessoryView.center.y
            detailButton.center.y = accessoryView.center.y
            cell.accessoryView = accessoryView
            cell.selectionStyle = .none
            hideUnknownSwitch.isOn = Defaults.isHideUnknownOn
        case "HideOtpFields".localize():
            cell.accessoryType = .none
            let detailButton = UIButton(type: .detailDisclosure)
            hideOTPSwitch.frame = CGRect(x: detailButton.bounds.width + 10, y: 0, width: hideOTPSwitch.bounds.width, height: hideOTPSwitch.bounds.height)
            detailButton.frame = CGRect(x: 0, y: 5, width: detailButton.bounds.width, height: detailButton.bounds.height)
            detailButton.addTarget(self, action: #selector(GeneralSettingsTableViewController.tapHideOTPSwitchDetailButton(_:)), for: UIControl.Event.touchDown)
            let accessoryView = UIView(frame: CGRect(x: 0, y: 0, width: detailButton.bounds.width + hideOTPSwitch.bounds.width + 10, height: cell.contentView.bounds.height))
            accessoryView.addSubview(detailButton)
            accessoryView.addSubview(hideOTPSwitch)
            hideOTPSwitch.center.y = accessoryView.center.y
            detailButton.center.y = accessoryView.center.y
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
            hidePasswordImagesSwitch.frame = CGRect(x: detailButton.bounds.width + 10, y: 0, width: hidePasswordImagesSwitch.bounds.width, height: hidePasswordImagesSwitch.bounds.height)
            detailButton.frame = CGRect(x: 0, y: 5, width: detailButton.bounds.width, height: detailButton.bounds.height)
            detailButton.addTarget(self, action: #selector(GeneralSettingsTableViewController.tapHidePasswordImagesSwitchDetailButton(_:)), for: UIControl.Event.touchDown)
            let accessoryView = UIView(frame: CGRect(x: 0, y: 0, width: detailButton.bounds.width + hidePasswordImagesSwitch.bounds.width + 10, height: cell.contentView.bounds.height))
            accessoryView.addSubview(detailButton)
            accessoryView.addSubview(hidePasswordImagesSwitch)
            hidePasswordImagesSwitch.center.y = accessoryView.center.y
            detailButton.center.y = accessoryView.center.y
            cell.accessoryView = accessoryView
            cell.selectionStyle = .none
            hidePasswordImagesSwitch.isOn = Defaults.isHidePasswordImagesOn
        default:
            break
        }
        return cell
    }

    @objc
    func tapHideUnknownSwitchDetailButton(_: Any?) {
        let alertMessage = "HideUnknownFieldsExplanation.".localize()
        let alertTitle = "HideUnknownFields".localize()
        Utils.alert(title: alertTitle, message: alertMessage, controller: self, completion: nil)
    }

    @objc
    func tapHideOTPSwitchDetailButton(_: Any?) {
        let keywordsString = Constants.OTP_KEYWORDS.joined(separator: ", ")
        let alertMessage = "HideOtpFieldsExplanation.".localize(keywordsString)
        let alertTitle = "HideOtpFields".localize()
        Utils.alert(title: alertTitle, message: alertMessage, controller: self, completion: nil)
    }

    @objc
    func tapHidePasswordImagesSwitchDetailButton(_: Any?) {
        let alertMessage = "HidePasswordImagesExplanation.".localize()
        let alertTitle = "HidePasswordImages".localize()
        Utils.alert(title: alertTitle, message: alertMessage, controller: self, completion: nil)
    }

    @objc
    func hideUnknownSwitchAction(_: Any?) {
        Defaults.isHideUnknownOn = hideUnknownSwitch.isOn
        NotificationCenter.default.post(name: .passwordDetailDisplaySettingChanged, object: nil)
    }

    @objc
    func hideOTPSwitchAction(_: Any?) {
        Defaults.isHideOTPOn = hideOTPSwitch.isOn
        NotificationCenter.default.post(name: .passwordDetailDisplaySettingChanged, object: nil)
    }

    @objc
    func rememberPGPPassphraseSwitchAction(_: Any?) {
        Defaults.isRememberPGPPassphraseOn = rememberPGPPassphraseSwitch.isOn
        if rememberPGPPassphraseSwitch.isOn == false {
            AppKeychain.shared.removeAllContent(withPrefix: Globals.pgpKeyPassphrase)
        }
    }

    @objc
    func rememberGitCredentialPassphraseSwitchAction(_: Any?) {
        Defaults.isRememberGitCredentialPassphraseOn = rememberGitCredentialPassphraseSwitch.isOn
        if rememberGitCredentialPassphraseSwitch.isOn == false {
            passwordStore.gitSSHPrivateKeyPassphrase = nil
            passwordStore.gitPassword = nil
        }
    }

    @objc
    func showFolderSwitchAction(_: Any?) {
        Defaults.isShowFolderOn = showFolderSwitch.isOn
        NotificationCenter.default.post(name: .passwordDisplaySettingChanged, object: nil)
    }

    @objc
    func hidePasswordImagesSwitchAction(_: Any?) {
        Defaults.isHidePasswordImagesOn = hidePasswordImagesSwitch.isOn
        NotificationCenter.default.post(name: .passwordDetailDisplaySettingChanged, object: nil)
    }
}
