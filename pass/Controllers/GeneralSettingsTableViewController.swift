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
    
    let hideUnknownSwitch = UISwitch(frame: CGRect.zero)

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
            cell.accessoryView = hideUnknownSwitch
            cell.selectionStyle = .none
            hideUnknownSwitch.addTarget(self, action: #selector(hideUnknownSwitchAction(_:)), for: UIControlEvents.valueChanged)
            hideUnknownSwitch.isOn = Defaults[.isHideUnknownOn]
        }
        return cell
    }
    
    func hideUnknownSwitchAction(_ sender: Any?) {
        Defaults[.isHideUnknownOn] = hideUnknownSwitch.isOn
    }
    
}
