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
    
    let hideUnknownSwitch = UISwitch()

    override func viewDidLoad() {
        navigationItemTitle = "General"
        tableData = [
            // section 0
            [[.title: "About Repository", .action: "segue", .link: "showAboutRepositorySegue"],],
            [[.title: "Hide Unkonwn Fields", .action: "none",],],

        ]
        super.viewDidLoad()

    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell =  super.tableView(tableView, cellForRowAt: indexPath)
        if indexPath == IndexPath(row: 0, section: 1) {
            cell.accessoryType = .none
            hideUnknownSwitch.onTintColor = UIColor(displayP3Red: 0, green: 122.0/255, blue: 1, alpha: 1)
            hideUnknownSwitch.sizeToFit()
            let detailButton = UIButton(type: .detailDisclosure)
            hideUnknownSwitch.frame = CGRect(x: detailButton.bounds.width+10, y: 0, width: hideUnknownSwitch.bounds.width, height: hideUnknownSwitch.bounds.height)
            detailButton.frame = CGRect(x: 0, y: 5, width: detailButton.bounds.width, height: detailButton.bounds.height)
            detailButton.addTarget(self, action: #selector(GeneralSettingsTableViewController.tapHideUnknownSwitchDetailButton(_:)), for: UIControlEvents.touchDown)
            let accessoryView = UIView(frame: CGRect(x: 0, y: 0, width: detailButton.bounds.width + hideUnknownSwitch.bounds.width+10, height: hideUnknownSwitch.bounds.height))
            accessoryView.addSubview(detailButton)
            accessoryView.addSubview(hideUnknownSwitch)
            cell.accessoryView = accessoryView
            cell.selectionStyle = .none
            hideUnknownSwitch.addTarget(self, action: #selector(hideUnknownSwitchAction(_:)), for: UIControlEvents.valueChanged)
            hideUnknownSwitch.isOn = Defaults[.isHideUnknownOn]
        }
        return cell
    }
    
    func tapHideUnknownSwitchDetailButton(_ sender: Any?) {
        print("tap")
        let alertMessage = "Only \"key: value\" format in additional fields is supported. Unsupported fields will be given \"unkown\" keys. Turn on this switch to hide unsupported fields."
        let alert = UIAlertController(title: "Hide Unknown Fields", message: alertMessage, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    func hideUnknownSwitchAction(_ sender: Any?) {
        Defaults[.isHideUnknownOn] = hideUnknownSwitch.isOn
    }
    
}
