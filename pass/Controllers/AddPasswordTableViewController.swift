//
//  AddPasswordTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 10/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit

class AddPasswordTableViewController: UITableViewController {
    let tableTitles = ["name", "password", "additions"]
    var password: Password?

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UINib(nibName: "TextFieldTableViewCell", bundle: nil), forCellReuseIdentifier: "textFieldCell")
        tableView.register(UINib(nibName: "TextViewTableViewCell", bundle: nil), forCellReuseIdentifier: "textViewCell")

        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 48
        tableView.allowsSelection = false
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return tableTitles.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableTitles[indexPath.section] == "additions" {
            let cell = tableView.dequeueReusableCell(withIdentifier: "textViewCell", for: indexPath) as! TextViewTableViewCell
            cell.contentTextView.text = ""
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "textFieldCell", for: indexPath) as! TextFieldTableViewCell
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        print(section)
        let headerView = UITableViewHeaderFooterView()
        headerView.textLabel?.text = tableTitles[section].uppercased()
        return headerView
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "saveAddPasswordSegue" {
            let nameCell = getCellForName(name: "name")! as! TextFieldTableViewCell
            let passwordCell = getCellForName(name: "password")! as! TextFieldTableViewCell
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
}
