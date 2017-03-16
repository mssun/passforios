//
//  AddPasswordTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 10/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import SwiftyUserDefaults

class AddPasswordTableViewController: PasswordEditorTableViewController {
    
    var password: Password?
    var tempContent: String = ""

    override func viewDidLoad() {
        tableData = [
            [[.type: PasswordEditorCellType.textFieldCell, .title: "name"]],
            [[.type: PasswordEditorCellType.fillPasswordCell, .title: "password"],
             [.type: PasswordEditorCellType.passwordLengthCell, .title: "passwordlength"]],
            [[.type: PasswordEditorCellType.textViewCell, .title: "additions"]],
        ]
        super.viewDidLoad()
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "saveAddPasswordSegue" {
            // check PGP key
            if Defaults[.pgpKeyID] == nil {
                let alertTitle = "Cannot Add Password"
                let alertMessage = "PGP Key is not set. Please set your PGP Key first."
                Utils.alert(title: alertTitle, message: alertMessage, controller: self, completion: nil)
                return false
            }
            // check name
            let nameCell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as! TextFieldTableViewCell
            if nameCell.getContent()!.isEmpty {
                let alertTitle = "Cannot Add Password"
                let alertMessage = "Please fill in the name."
                Utils.alert(title: alertTitle, message: alertMessage, controller: self, completion: nil)
                return false
            }
        }
        return true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "saveAddPasswordSegue" {let cells = tableView.visibleCells
            var cellContents = [String: String]()
            for cell in cells {
                let indexPath = tableView.indexPath(for: cell)!
                let contentCell = cell as! ContentTableViewCell
                let cellTitle = tableData[indexPath.section][indexPath.row][.title] as! String
                if let cellContent = contentCell.getContent() {
                    cellContents[cellTitle] = cellContent
                }
            }
            var plainText = ""
            if cellContents["additions"]! != "" {
                plainText = "\(cellContents["password"]!)\n\(cellContents["additions"]!)"
            } else {
                plainText = "\(cellContents["password"]!)"
            }
            password = Password(name: cellContents["name"]!, plainText: plainText)
        }
    }
}
