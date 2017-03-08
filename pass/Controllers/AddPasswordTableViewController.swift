//
//  AddPasswordTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 10/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit

class AddPasswordTableViewController: UITableViewController, FillPasswordTableViewCellDelegate {
    let tableTitles = ["name", "password", "additions"]
    let tableRowsInSection = [1, 2, 1]
    var password: Password?
    
    var passwordLengthCell: SliderTableViewCell?

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UINib(nibName: "TextFieldTableViewCell", bundle: nil), forCellReuseIdentifier: "textFieldCell")
        tableView.register(UINib(nibName: "TextViewTableViewCell", bundle: nil), forCellReuseIdentifier: "textViewCell")
        tableView.register(UINib(nibName: "FillPasswordTableViewCell", bundle: nil), forCellReuseIdentifier: "fillPasswordCell")
        tableView.register(UINib(nibName: "SliderTableViewCell", bundle: nil), forCellReuseIdentifier: "passwordLengthCell")

        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 48
        tableView.allowsSelection = false
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableRowsInSection[section]
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return tableTitles.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch tableTitles[indexPath.section] {
        case "additions":
            let cell = tableView.dequeueReusableCell(withIdentifier: "textViewCell", for: indexPath) as! TextViewTableViewCell
            cell.contentTextView.text = ""
            return cell
        case "password":
            switch indexPath.row {
            case 0:
                let cell = tableView.dequeueReusableCell(withIdentifier: "fillPasswordCell", for: indexPath) as! FillPasswordTableViewCell
                cell.delegate = self
                return cell
            default:
                passwordLengthCell = (tableView.dequeueReusableCell(withIdentifier: "passwordLengthCell", for: indexPath) as! SliderTableViewCell)
                passwordLengthCell!.reset(title: "Length", minimumValue: 1, maximumValue: Globals.passwordMaximumLength, defaultValue: Globals.passwordDefaultLength)
                return passwordLengthCell!
            }
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: "textFieldCell", for: indexPath) as! TextFieldTableViewCell
            cell.contentTextField.placeholder = tableTitles[indexPath.section]
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UITableViewHeaderFooterView()
        headerView.textLabel?.text = tableTitles[section].uppercased()
        return headerView
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "saveAddPasswordSegue" {
            let nameCell = getCellForName(name: "name")! as! TextFieldTableViewCell
            let passwordCell = getCellForName(name: "password")! as! FillPasswordTableViewCell
            let additionsCell = getCellForName(name: "additions")! as! TextViewTableViewCell
            password = Password(name: nameCell.contentTextField.text!, plainText: "\(passwordCell.contentTextField.text!)\n\(additionsCell.contentTextView.text!)")
        }
    }
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 44
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.1
    }
    
    func getCellAt(section: Int) -> UITableViewCell? {
        return tableView.cellForRow(at: IndexPath(row: 0, section: section))
    }
    
    func getCellForName(name: String) -> UITableViewCell? {
        let index = tableTitles.index(of: name)!
        return getCellAt(section: Int(index))
    }
    
    func generatePassword() -> String {
        let length = passwordLengthCell?.roundedValue ?? Globals.passwordDefaultLength
        return Utils.generatePassword(length: length)
    }
}
