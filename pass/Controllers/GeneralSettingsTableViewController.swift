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
        uiSwitch.onTintColor = Globals.blue
        uiSwitch.sizeToFit()
        uiSwitch.addTarget(self, action: #selector(hideUnknownSwitchAction(_:)), for: UIControlEvents.valueChanged)
        return uiSwitch
    }()
    
    let hideOTPSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = Globals.blue
        uiSwitch.sizeToFit()
        uiSwitch.addTarget(self, action: #selector(hideOTPSwitchAction(_:)), for: UIControlEvents.valueChanged)
        return uiSwitch
    }()
    
    let rememberPGPPassphraseSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = Globals.blue
        uiSwitch.sizeToFit()
        uiSwitch.addTarget(self, action: #selector(rememberPGPPassphraseSwitchAction(_:)), for: UIControlEvents.valueChanged)
        uiSwitch.isOn = SharedDefaults[.isRememberPGPPassphraseOn]
        return uiSwitch
    }()
    
    let rememberGitCredentialPassphraseSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = Globals.blue
        uiSwitch.sizeToFit()
        uiSwitch.addTarget(self, action: #selector(rememberGitCredentialPassphraseSwitchAction(_:)), for: UIControlEvents.valueChanged)
        uiSwitch.isOn = SharedDefaults[.isRememberGitCredentialPassphraseOn]
        return uiSwitch
    }()
    
    let showFolderSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = Globals.blue
        uiSwitch.sizeToFit()
        uiSwitch.addTarget(self, action: #selector(showFolderSwitchAction(_:)), for: UIControlEvents.valueChanged)
        uiSwitch.isOn = SharedDefaults[.isShowFolderOn]
        return uiSwitch
    }()

    override func viewDidLoad() {
        tableData = [
            // section 0
            [[.title: "About Repository", .action: "segue", .link: "showAboutRepositorySegue"],],
            
            // section 1
            [
                [.title: "Password Generator Flavor", .action: "none", .style: CellDataStyle.value1],
            ],
            
            // section 2
            [
                [.title: "Remember PGP Key Passphrase", .action: "none",],
                [.title: "Remember Git Credential Passphrase", .action: "none",],
            ],
            [
                [.title: "Show Folders", .action: "none",],
                [.title: "Hide Unknown Fields", .action: "none",],
                [.title: "Hide OTP Fields", .action: "none",],
            ],

        ]
        super.viewDidLoad()
        
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell =  super.tableView(tableView, cellForRowAt: indexPath)
        switch cell.textLabel!.text! {
        case "Hide Unknown Fields":
            cell.accessoryType = .none
            let detailButton = UIButton(type: .detailDisclosure)
            hideUnknownSwitch.frame = CGRect(x: detailButton.bounds.width+10, y: 0, width: hideUnknownSwitch.bounds.width, height: hideUnknownSwitch.bounds.height)
            detailButton.frame = CGRect(x: 0, y: 5, width: detailButton.bounds.width, height: detailButton.bounds.height)
            detailButton.addTarget(self, action: #selector(GeneralSettingsTableViewController.tapHideUnknownSwitchDetailButton(_:)), for: UIControlEvents.touchDown)
            let accessoryView = UIView(frame: CGRect(x: 0, y: 0, width: detailButton.bounds.width + hideUnknownSwitch.bounds.width+10, height: hideUnknownSwitch.bounds.height))
            accessoryView.addSubview(detailButton)
            accessoryView.addSubview(hideUnknownSwitch)
            cell.accessoryView = accessoryView
            cell.selectionStyle = .none
            hideUnknownSwitch.isOn = SharedDefaults[.isHideUnknownOn]
        case "Hide OTP Fields":
            cell.accessoryType = .none
            let detailButton = UIButton(type: .detailDisclosure)
            hideOTPSwitch.frame = CGRect(x: detailButton.bounds.width+10, y: 0, width: hideOTPSwitch.bounds.width, height: hideOTPSwitch.bounds.height)
            detailButton.frame = CGRect(x: 0, y: 5, width: detailButton.bounds.width, height: detailButton.bounds.height)
            detailButton.addTarget(self, action: #selector(GeneralSettingsTableViewController.tapHideOTPSwitchDetailButton(_:)), for: UIControlEvents.touchDown)
            let accessoryView = UIView(frame: CGRect(x: 0, y: 0, width: detailButton.bounds.width + hideOTPSwitch.bounds.width+10, height: hideOTPSwitch.bounds.height))
            accessoryView.addSubview(detailButton)
            accessoryView.addSubview(hideOTPSwitch)
            cell.accessoryView = accessoryView
            cell.selectionStyle = .none
            hideOTPSwitch.isOn = SharedDefaults[.isHideOTPOn]
        case "Remember PGP Key Passphrase":
            cell.accessoryType = .none
            cell.selectionStyle = .none
            cell.accessoryView = rememberPGPPassphraseSwitch
        case "Remember Git Credential Passphrase":
            cell.accessoryType = .none
            cell.selectionStyle = .none
            cell.accessoryView = rememberGitCredentialPassphraseSwitch
        case "Show Folders":
            cell.accessoryType = .none
            cell.selectionStyle = .none
            cell.accessoryView = showFolderSwitch
        case "Password Generator Flavor":
            cell.accessoryType = .disclosureIndicator
            cell.detailTextLabel?.text = SharedDefaults[.passwordGeneratorFlavor]
        default: break
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        super.tableView(tableView, didSelectRowAt: indexPath)
        let cell = tableView.cellForRow(at: indexPath)!
        if cell.textLabel!.text! == "Password Generator Flavor" {
            tableView.deselectRow(at: indexPath, animated: true)
            showPasswordGeneratorFlavorActionSheet(sourceCell: cell)
        }
    }
    
    func showPasswordGeneratorFlavorActionSheet(sourceCell: UITableViewCell) {
        let optionMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        var randomFlavorActionTitle = ""
        var appleFlavorActionTitle = ""
        if SharedDefaults[.passwordGeneratorFlavor] == "Random" {
            randomFlavorActionTitle = "✓ Random String"
            appleFlavorActionTitle = "Apple's Keychain Style"
        } else {
            randomFlavorActionTitle = "Random String"
            appleFlavorActionTitle = "✓ Apple's Keychain Style"
        }
        let randomFlavorAction = UIAlertAction(title: randomFlavorActionTitle, style: .default) { _ in
            SharedDefaults[.passwordGeneratorFlavor] = "Random"
            sourceCell.detailTextLabel?.text = "Random"
        }
        
        let appleFlavorAction = UIAlertAction(title: appleFlavorActionTitle, style: .default) { _ in
            SharedDefaults[.passwordGeneratorFlavor] = "Apple"
            sourceCell.detailTextLabel?.text = "Apple"
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        optionMenu.addAction(randomFlavorAction)
        optionMenu.addAction(appleFlavorAction)
        optionMenu.addAction(cancelAction)
        optionMenu.popoverPresentationController?.sourceView = sourceCell
        optionMenu.popoverPresentationController?.sourceRect = sourceCell.bounds
        self.present(optionMenu, animated: true, completion: nil)
    }
    
    @objc func tapHideUnknownSwitchDetailButton(_ sender: Any?) {
        let alertMessage = "Only \"key: value\" format in additional fields is supported. Unsupported fields will be given \"unknown\" keys. Turn on this switch to hide unsupported fields."
        let alertTitle = "Hide Unknown Fields"
        Utils.alert(title: alertTitle, message: alertMessage, controller: self, completion: nil)
    }
    
    @objc func tapHideOTPSwitchDetailButton(_ sender: Any?) {
        let keywordsString = Password.otpKeywords.joined(separator: ",")
        let alertMessage = "Turn on this switch to hide the fields related to one time passwords (i.e., \(keywordsString))."
        let alertTitle = "Hide One Time Password Fields"
        Utils.alert(title: alertTitle, message: alertMessage, controller: self, completion: nil)
    }
    
    @objc func hideUnknownSwitchAction(_ sender: Any?) {
        SharedDefaults[.isHideUnknownOn] = hideUnknownSwitch.isOn
        NotificationCenter.default.post(name: .passwordDetailDisplaySettingChanged, object: nil)
    }
    
    @objc func hideOTPSwitchAction(_ sender: Any?) {
        SharedDefaults[.isHideOTPOn] = hideOTPSwitch.isOn
        NotificationCenter.default.post(name: .passwordDetailDisplaySettingChanged, object: nil)
    }
    
    @objc func rememberPGPPassphraseSwitchAction(_ sender: Any?) {
        SharedDefaults[.isRememberPGPPassphraseOn] = rememberPGPPassphraseSwitch.isOn
        if rememberPGPPassphraseSwitch.isOn == false {
            passwordStore.pgpKeyPassphrase = nil
        }
    }
    
    @objc func rememberGitCredentialPassphraseSwitchAction(_ sender: Any?) {
        SharedDefaults[.isRememberGitCredentialPassphraseOn] = rememberGitCredentialPassphraseSwitch.isOn
        if rememberGitCredentialPassphraseSwitch.isOn == false {
            passwordStore.gitSSHPrivateKeyPassphrase = nil
            passwordStore.gitPassword = nil
        }
    }
    
    @objc func showFolderSwitchAction(_ sender: Any?) {
        SharedDefaults[.isShowFolderOn] = showFolderSwitch.isOn
        NotificationCenter.default.post(name: .passwordDisplaySettingChanged, object: nil)
    }
    
}
