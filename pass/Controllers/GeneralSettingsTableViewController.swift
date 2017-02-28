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
    let rememberPassphraseSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = Globals.blue
        uiSwitch.sizeToFit()
        uiSwitch.addTarget(self, action: #selector(rememberPassphraseSwitchAction(_:)), for: UIControlEvents.valueChanged)
        uiSwitch.isOn = Defaults[.isRememberPassphraseOn]
        return uiSwitch
    }()

    override func viewDidLoad() {
        navigationItemTitle = "General"
        tableData = [
            // section 0
            [[.title: "About Repository", .action: "segue", .link: "showAboutRepositorySegue"],],
            
            // section 1
            [
                [.title: "Remember Phassphrase", .action: "none",],
                [.title: "Hide Unknown Fields", .action: "none",],
             ],

        ]
        super.viewDidLoad()
        
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell =  super.tableView(tableView, cellForRowAt: indexPath)
        if cell.textLabel?.text == "Hide Unknown Fields" {
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
        } else if cell.textLabel?.text == "Remember Phassphrase" {
            cell.accessoryType = .none
            cell.selectionStyle = .none
            cell.accessoryView = rememberPassphraseSwitch
        }
        return cell
    }
    
    func tapHideUnknownSwitchDetailButton(_ sender: Any?) {
        let alertMessage = "Only \"key: value\" format in additional fields is supported. Unsupported fields will be given \"unkown\" keys. Turn on this switch to hide unsupported fields."
        let alertTitle = "Hide Unknown Fields"
        Utils.alert(title: alertTitle, message: alertMessage, controller: self, completion: nil)
    }
    
    func hideUnknownSwitchAction(_ sender: Any?) {
        Defaults[.isHideUnknownOn] = hideUnknownSwitch.isOn
    }
    
    func rememberPassphraseSwitchAction(_ sender: Any?) {
        Defaults[.isRememberPassphraseOn] = rememberPassphraseSwitch.isOn
        if rememberPassphraseSwitch.isOn == false {
            PasswordStore.shared.pgpKeyPassphrase = nil
        }
    }
    
}
