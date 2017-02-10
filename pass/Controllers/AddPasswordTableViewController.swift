//
//  AddPasswordTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 10/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit

class AddPasswordTableViewController: UITableViewController {
    let tableTitles = ["name", "password"]
    var password: Password?

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UINib(nibName: "TextFieldTableViewCell", bundle: nil), forCellReuseIdentifier: "textFieldCell")
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 52
        tableView.allowsSelection = false
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableTitles.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "textFieldCell", for: indexPath) as! TextFieldTableViewCell
        cell.titleLabel.text = tableTitles[indexPath.row]
        return cell
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let name = getCellForName(name: "name")!.contentTextField.text ?? ""
        let passwordText = getCellForName(name: "password")!.contentTextField.text ?? ""
//        let additions = getCellForName(name: "additions")!.contentTextField.text ?? ""
//        let additionSplit = additions.characters.split(separator: ":").map(String.init)
//        print(additionSplit)
//        let additionField = AdditionField(title: additionSplit[0], content: additionSplit[1])
        password = Password(name: name, username: "", password: passwordText, additions: [])
    }
    
    func getCellAt(row: Int) -> TextFieldTableViewCell? {
        return tableView.cellForRow(at: IndexPath(row: row, section: 0)) as? TextFieldTableViewCell
    }
    
    func getCellForName(name: String) -> TextFieldTableViewCell? {
        let index = tableTitles.index(of: name)!
        return getCellAt(row: Int(index))
    }
}
