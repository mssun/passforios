//
//  GeneralSettingsTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 9/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import SwiftyUserDefaults

class GeneralSettingsTableViewController: BasicStaticTableViewController {
    
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
    
    let rememberPassphraseSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = Globals.blue
        uiSwitch.sizeToFit()
        uiSwitch.addTarget(self, action: #selector(rememberPassphraseSwitchAction(_:)), for: UIControlEvents.valueChanged)
        uiSwitch.isOn = Defaults[.isRememberPassphraseOn]
        return uiSwitch
    }()
    
    let showFolderSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = Globals.blue
        uiSwitch.sizeToFit()
        uiSwitch.addTarget(self, action: #selector(showFolderSwitchAction(_:)), for: UIControlEvents.valueChanged)
        uiSwitch.isOn = Defaults[.isShowFolderOn]
        return uiSwitch
    }()

    override func viewDidLoad() {
        navigationItemTitle = "General"
        tableData = [
            // section 0
            [[.title: "About Repository", .action: "segue", .link: "showAboutRepositorySegue"],],
            
            // section 1
            [
                [.title: "Password Generator Flavor", .action: "none", .style: CellDataStyle.value1],
            ],
            
            // section 2
            [
                [.title: "Remember Passphrase", .action: "none",],
            ],
            [
                [.title: "Show Folder", .action: "none",],
                [.title: "Hide Unknown Fields", .action: "none",],
                [.title: "Hide One Time Password Fields", .action: "none",],
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
            hideUnknownSwitch.isOn = Defaults[.isHideUnknownOn]
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
            hideOTPSwitch.isOn = Defaults[.isHideOTPOn]
        case "Remember Passphrase":
            cell.accessoryType = .none
            cell.selectionStyle = .none
            cell.accessoryView = rememberPassphraseSwitch
        case "Show Folder":
            cell.accessoryType = .none
            cell.selectionStyle = .none
            cell.accessoryView = showFolderSwitch
        case "Password Generator Flavor":
            cell.accessoryType = .disclosureIndicator
            cell.detailTextLabel?.text = Defaults[.passwordGeneratorFlavor]
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
        if Defaults[.passwordGeneratorFlavor] == "Random" {
            randomFlavorActionTitle = "✓ Random String"
            appleFlavorActionTitle = "Apple's Keychain Style"
        } else {
            randomFlavorActionTitle = "Random String"
            appleFlavorActionTitle = "✓ Apple's Keychain Style"
        }
        let randomFlavorAction = UIAlertAction(title: randomFlavorActionTitle, style: .default) { _ in
            Defaults[.passwordGeneratorFlavor] = "Random"
            sourceCell.detailTextLabel?.text = "Random"
        }
        
        let appleFlavorAction = UIAlertAction(title: appleFlavorActionTitle, style: .default) { _ in
            Defaults[.passwordGeneratorFlavor] = "Apple"
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
    
    func tapHideUnknownSwitchDetailButton(_ sender: Any?) {
        let alertMessage = "Only \"key: value\" format in additional fields is supported. Unsupported fields will be given \"unkown\" keys. Turn on this switch to hide unsupported fields."
        let alertTitle = "Hide Unknown Fields"
        Utils.alert(title: alertTitle, message: alertMessage, controller: self, completion: nil)
    }
    
    func tapHideOTPSwitchDetailButton(_ sender: Any?) {
        let keywordsString = Password.otpKeywords.joined(separator: ",")
        let alertMessage = "Turn on this switch to hide the fields related to one time passwords (i.e., \(keywordsString))."
        let alertTitle = "Hide One Time Password Fields"
        Utils.alert(title: alertTitle, message: alertMessage, controller: self, completion: nil)
    }
    
    func hideUnknownSwitchAction(_ sender: Any?) {
        Defaults[.isHideUnknownOn] = hideUnknownSwitch.isOn
    }
    
    func hideOTPSwitchAction(_ sender: Any?) {
        Defaults[.isHideOTPOn] = hideOTPSwitch.isOn
    }
    
    func rememberPassphraseSwitchAction(_ sender: Any?) {
        Defaults[.isRememberPassphraseOn] = rememberPassphraseSwitch.isOn
        if rememberPassphraseSwitch.isOn == false {
            PasswordStore.shared.pgpKeyPassphrase = nil
        }
    }
    
    func showFolderSwitchAction(_ sender: Any?) {
        Defaults[.isShowFolderOn] = showFolderSwitch.isOn
        NotificationCenter.default.post(Notification(name: Notification.Name("passwordUpdated")))
    }
    
}
