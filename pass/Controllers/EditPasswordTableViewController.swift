//
//  EditPasswordTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 12/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit

class EditPasswordTableViewController: PasswordEditorTableViewController {
    override func viewDidLoad() {
        tableData = [
            [[.type: PasswordEditorCellType.textFieldCell, .title: "name", .content: password!.name]],
            [[.type: PasswordEditorCellType.fillPasswordCell, .title: "password", .content: password!.password]],
            [[.type: PasswordEditorCellType.textViewCell, .title: "additions", .content: password!.getAdditionsPlainText()]],
            [[.type: PasswordEditorCellType.deletePasswordCell]],
        ]
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
            password!.updatePassword(name: cellContents["name"]!, plainText: plainText)
        }
    }

}
