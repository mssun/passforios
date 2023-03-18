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

    private lazy var hideUnknownSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = Colors.systemBlue
        uiSwitch.sizeToFit()
        uiSwitch.addTarget(self, action: #selector(hideUnknownSwitchAction), for: UIControl.Event.valueChanged)
        return uiSwitch
    }()

    private lazy var hideOTPSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = Colors.systemBlue
        uiSwitch.sizeToFit()
        uiSwitch.addTarget(self, action: #selector(hideOTPSwitchAction), for: UIControl.Event.valueChanged)
        return uiSwitch
    }()

    private lazy var autoCopyOTPSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = Colors.systemBlue
        uiSwitch.sizeToFit()
        uiSwitch.addTarget(self, action: #selector(autoCopyOTPSwitchAction), for: UIControl.Event.valueChanged)
        return uiSwitch
    }()

    private lazy var rememberPGPPassphraseSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = Colors.systemBlue
        uiSwitch.sizeToFit()
        uiSwitch.addTarget(self, action: #selector(rememberPGPPassphraseSwitchAction), for: UIControl.Event.valueChanged)
        uiSwitch.isOn = Defaults.isRememberPGPPassphraseOn
        return uiSwitch
    }()

    private lazy var rememberGitCredentialPassphraseSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = Colors.systemBlue
        uiSwitch.sizeToFit()
        uiSwitch.addTarget(self, action: #selector(rememberGitCredentialPassphraseSwitchAction), for: UIControl.Event.valueChanged)
        uiSwitch.isOn = Defaults.isRememberGitCredentialPassphraseOn
        return uiSwitch
    }()

    private lazy var enableGPGIDSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = Colors.systemBlue
        uiSwitch.sizeToFit()
        uiSwitch.addTarget(self, action: #selector(enableGPGIDSwitchAction), for: UIControl.Event.valueChanged)
        uiSwitch.isOn = Defaults.isEnableGPGIDOn
        return uiSwitch
    }()

    private lazy var showFolderSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = Colors.systemBlue
        uiSwitch.sizeToFit()
        uiSwitch.addTarget(self, action: #selector(showFolderSwitchAction), for: UIControl.Event.valueChanged)
        uiSwitch.isOn = Defaults.isShowFolderOn
        return uiSwitch
    }()

    private lazy var hidePasswordImagesSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = Colors.systemBlue
        uiSwitch.sizeToFit()
        uiSwitch.addTarget(self, action: #selector(hidePasswordImagesSwitchAction), for: UIControl.Event.valueChanged)
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
                [.title: "EnableGPGID".localize(), .action: "none"],
                [.title: "ShowFolders".localize(), .action: "none"],
                [.title: "HidePasswordImages".localize(), .action: "none"],
                [.title: "HideUnknownFields".localize(), .action: "none"],
                [.title: "HideOtpFields".localize(), .action: "none"],
                [.title: "AutoCopyOTP".localize(), .action: "none"],
            ],
        ]
        super.viewDidLoad()
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        cell.accessoryType = .none
        cell.selectionStyle = .none
        switch cell.textLabel!.text! {
        case "AboutRepository".localize():
            cell.accessoryType = .disclosureIndicator
        case "HideUnknownFields".localize():
            hideUnknownSwitch.isOn = Defaults.isHideUnknownOn
            addDetailButton(to: cell, for: hideUnknownSwitch, with: #selector(tapHideUnknownSwitchDetailButton))
        case "HideOtpFields".localize():
            hideOTPSwitch.isOn = Defaults.isHideOTPOn
            addDetailButton(to: cell, for: hideOTPSwitch, with: #selector(tapHideOTPSwitchDetailButton))
        case "RememberPgpKeyPassphrase".localize():
            cell.accessoryView = rememberPGPPassphraseSwitch
        case "RememberGitCredentialPassphrase".localize():
            cell.accessoryView = rememberGitCredentialPassphraseSwitch
        case "ShowFolders".localize():
            cell.accessoryView = showFolderSwitch
        case "EnableGPGID".localize():
            cell.accessoryView = enableGPGIDSwitch
        case "HidePasswordImages".localize():
            hidePasswordImagesSwitch.isOn = Defaults.isHidePasswordImagesOn
            addDetailButton(to: cell, for: hidePasswordImagesSwitch, with: #selector(tapHidePasswordImagesSwitchDetailButton))
        case "AutoCopyOTP".localize():
            autoCopyOTPSwitch.isOn = Defaults.autoCopyOTP
            addDetailButton(to: cell, for: autoCopyOTPSwitch, with: #selector(tapAutoCopyOTPSwitchDetailButton))
        default:
            break
        }
        return cell
    }

    private func addDetailButton(to cell: UITableViewCell, for uiSwitch: UISwitch, with action: Selector) {
        let detailButton = UIButton(type: .detailDisclosure)
        uiSwitch.frame = CGRect(
            x: detailButton.bounds.width + 10,
            y: 0,
            width: uiSwitch.bounds.width,
            height: uiSwitch.bounds.height
        )
        detailButton.frame = CGRect(
            x: 0,
            y: 5,
            width: detailButton.bounds.width,
            height: detailButton.bounds.height
        )
        detailButton.addTarget(self, action: action, for: UIControl.Event.touchDown)
        let accessoryViewFrame = CGRect(
            x: 0,
            y: 0,
            width: detailButton.bounds.width + uiSwitch.bounds.width + 10,
            height: cell.contentView.bounds.height
        )
        let accessoryView = UIView(frame: accessoryViewFrame)
        accessoryView.addSubview(detailButton)
        accessoryView.addSubview(uiSwitch)
        uiSwitch.center.y = accessoryView.center.y
        detailButton.center.y = accessoryView.center.y
        cell.accessoryView = accessoryView
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
    func tapAutoCopyOTPSwitchDetailButton(_: Any?) {
        let alertMessage = "AutoCopyOTPExplanation.".localize()
        let alertTitle = "AutoCopyOTP".localize()
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
    func autoCopyOTPSwitchAction(_: Any?) {
        Defaults.autoCopyOTP = autoCopyOTPSwitch.isOn
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
    func enableGPGIDSwitchAction(_: Any?) {
        Defaults.isEnableGPGIDOn = enableGPGIDSwitch.isOn
    }

    @objc
    func hidePasswordImagesSwitchAction(_: Any?) {
        Defaults.isHidePasswordImagesOn = hidePasswordImagesSwitch.isOn
        NotificationCenter.default.post(name: .passwordDetailDisplaySettingChanged, object: nil)
    }
}
