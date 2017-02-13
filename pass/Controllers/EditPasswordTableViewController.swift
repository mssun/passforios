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
        super.viewDidLoad()
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "saveEditPasswordSegue" {
            let nameCell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as! ContentTableViewCell
            if nameCell.getContent() != password?.name {
                let alertMessage = "Editing name is not supported."
                let alert = UIAlertController(title: "Cannot Save Edit", message: alertMessage, preferredStyle: UIAlertControllerStyle.alert)
                alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                self.present(alert, animated: true) {
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
            password!.updatePassword(name: cellContents["name"]!, plainText: "\(cellContents["password"]!)\n\(cellContents["additions"]!)")
        }
    }

}
