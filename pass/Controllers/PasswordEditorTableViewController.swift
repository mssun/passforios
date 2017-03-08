//
//  PasswordEditorTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 12/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
enum PasswordEditorCellType {
    case textFieldCell, textViewCell, fillPasswordCell, passwordLengthCell
}

enum PasswordEditorCellKey {
    case type, title, content, placeholders
}

class PasswordEditorTableViewController: UITableViewController, FillPasswordTableViewCellDelegate {
    var navigationItemTitle: String?
    var tableData = [
        [Dictionary<PasswordEditorCellKey, Any>]
    ]()
    var sectionHeaderTitles = ["name", "password", "additions"].map {$0.uppercased()}
    var sectionFooterTitles = ["", "", "It is recommended to use \"key: value\" format to store additional fields as follows:\n  url: https://www.apple.com\n  username: passforios@gmail.com."]
    
    var passwordLengthCell: SliderTableViewCell?

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = navigationItemTitle
        tableView.register(UINib(nibName: "TextFieldTableViewCell", bundle: nil), forCellReuseIdentifier: "textFieldCell")
        tableView.register(UINib(nibName: "TextViewTableViewCell", bundle: nil), forCellReuseIdentifier: "textViewCell")
        tableView.register(UINib(nibName: "FillPasswordTableViewCell", bundle: nil), forCellReuseIdentifier: "fillPasswordCell")
        tableView.register(UINib(nibName: "SliderTableViewCell", bundle: nil), forCellReuseIdentifier: "passwordLengthCell")
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 48
        tableView.allowsSelection = false
        self.tableView.sectionFooterHeight = UITableViewAutomaticDimension;
        self.tableView.estimatedSectionFooterHeight = 0;
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellData = tableData[indexPath.section][indexPath.row]
        var cell = ContentTableViewCell()
        
        switch cellData[PasswordEditorCellKey.type] as! PasswordEditorCellType {
        case .textViewCell:
            cell = tableView.dequeueReusableCell(withIdentifier: "textViewCell", for: indexPath) as! ContentTableViewCell
        case .fillPasswordCell:
            let fillPasswordCell = tableView.dequeueReusableCell(withIdentifier: "fillPasswordCell", for: indexPath) as?FillPasswordTableViewCell
            fillPasswordCell?.delegate = self
            cell = fillPasswordCell!
        case .passwordLengthCell:
            passwordLengthCell = tableView.dequeueReusableCell(withIdentifier: "passwordLengthCell", for: indexPath) as? SliderTableViewCell
            passwordLengthCell?.reset(title: "Length", minimumValue: 1, maximumValue: Globals.passwordMaximumLength, defaultValue: Globals.passwordDefaultLength)
            cell = passwordLengthCell!
        default:
            cell = tableView.dequeueReusableCell(withIdentifier: "textFieldCell", for: indexPath) as! ContentTableViewCell
        }
        if let content = cellData[PasswordEditorCellKey.content] as? String {
            cell.setContent(content: content)
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 44
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return tableData.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableData[section].count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionHeaderTitles[section]
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sectionFooterTitles[section]
    }
    
    func generatePassword() -> String {
        let length = passwordLengthCell?.roundedValue ?? Globals.passwordDefaultLength
        return Utils.generatePassword(length: length)
    }
}
