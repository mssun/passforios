//
//  EditPasswordTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 12/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit

class EditPasswordTableViewController: PasswordEditorTableViewController {
    
    var password: Password?

    override func viewDidLoad() {
        tableData = [
            [[.type: PasswordEditorCellType.textFieldCell, .title: "name", .content: password!.name]],
            [[.type: PasswordEditorCellType.fillPasswordCell, .title: "password", .content: password!.password]],
            [[.type: PasswordEditorCellType.textViewCell, .title: "additions", .content: password!.getAdditionsPlainText()]],
        ]
        sectionHeaderTitles = ["name", "password", "additions"].map {$0.uppercased()}
        sectionFooterTitles = ["", "", "It is recommended to use \"key: value\" format to store additional fields as follows:\n  url: https://www.apple.com\n  username: passforios@gmail.com."]

        super.viewDidLoad()
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "saveEditPasswordSegue" {
            let nameCell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as! ContentTableViewCell
            if nameCell.getContent() != password?.name {
                let alertTitle = "Cannot Save Edit"
                let alertMessage = "Editing name is not supported."
                Utils.alert(title: alertTitle, message: alertMessage, controller: self) {
                    nameCell.setContent(content: self.password!.name)
                }
                return false
            }
        }
        return true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "saveEditPasswordSegue" {
            let cells = tableView.visibleCells
            var cellContents = [String: String]()
            for cell in cells {
                let indexPath = tableView.indexPath(for: cell)!
                let contentCell = cell as! ContentTableViewCell
                let cellTitle = tableData[indexPath.section][indexPath.row][.title] as! String
                cellContents[cellTitle] = contentCell.getContent()!
            }
            var plainText = ""
            if cellContents["additions"]! != "" {
                plainText = "\(cellContents["password"]!)\n\(cellContents["additions"]!)"
            } else {
                plainText = "\(cellContents["password"]!)"
            }
            password!.updatePassword(name: cellContents["name"]!, plainText: plainText)
        }
    }

}
