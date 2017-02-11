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
        tableView.estimatedRowHeight = 64
        tableView.allowsSelection = false
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableTitles.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableTitles[indexPath.row] == "additions" {
            let cell = tableView.dequeueReusableCell(withIdentifier: "textViewCell", for: indexPath) as! TextViewTableViewCell
            cell.titleLabel.text = tableTitles[indexPath.row]
            cell.contentTextView.text = ""
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "textFieldCell", for: indexPath) as! TextFieldTableViewCell
            cell.titleLabel.text = tableTitles[indexPath.row]
            return cell
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let nameCell = getCellForName(name: "name")! as! TextFieldTableViewCell
        let passwordCell = getCellForName(name: "password")! as! TextFieldTableViewCell
        let additionsCell = getCellForName(name: "additions")! as! TextViewTableViewCell
        password = Password(name: nameCell.contentTextField.text!, plainText: "\(passwordCell.contentTextField.text!)\n\(additionsCell.contentTextView.text!)")
    }
    
    func getCellAt(row: Int) -> UITableViewCell? {
        return tableView.cellForRow(at: IndexPath(row: row, section: 0))
    }
    
    func getCellForName(name: String) -> UITableViewCell? {
        let index = tableTitles.index(of: name)!
        return getCellAt(row: Int(index))
    }
}
