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
            [[.type: PasswordEditorCellType.textFieldCell, .title: "name", .content: password!.namePath]],
            [[.type: PasswordEditorCellType.fillPasswordCell, .title: "password", .content: password!.password],
             [.type: PasswordEditorCellType.passwordLengthCell, .title: "passwordlength"]],
            [[.type: PasswordEditorCellType.textViewCell, .title: "additions", .content: password!.getAdditionsPlainText()]],
            [[.type: PasswordEditorCellType.scanQRCodeCell],
             [.type: PasswordEditorCellType.deletePasswordCell]]
        ]
        super.viewDidLoad()
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "saveEditPasswordSegue" {
            if let nameCell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? ContentTableViewCell {
                if let name = nameCell.getContent(),
                    let path = name.stringByAddingPercentEncodingForRFC3986(),
                    let _ = URL(string: path) {
                    return true
                } else {
                    Utils.alert(title: "Cannot Save", message: "Password name is invalid.", controller: self, completion: nil)
                    return false
                }
            }
        }
        return true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if segue.identifier == "saveEditPasswordSegue" {
            let cells = tableView.visibleCells
            var cellContents = [String: String]()
            for cell in cells {
                if let indexPath = tableView.indexPath(for: cell),
                    let contentCell = cell as? ContentTableViewCell,
                    let cellTitle = tableData[indexPath.section][indexPath.row][.title] as? String,
                    let cellContent = contentCell.getContent() {
                    cellContents[cellTitle] = cellContent
                }
            }
            var plainText = ""
            if cellContents["additions"]! != "" {
                plainText = "\(cellContents["password"]!)\n\(cellContents["additions"]!)"
            } else {
                plainText = "\(cellContents["password"]!)"
            }
            let name = URL(string: cellContents["name"]!.stringByAddingPercentEncodingForRFC3986()!)!.lastPathComponent
            let url = URL(string: cellContents["name"]!.stringByAddingPercentEncodingForRFC3986()!)!.appendingPathExtension("gpg")
            if password!.plainText != plainText || password!.url!.path != url.path {
                password!.updatePassword(name: name, url: url, plainText: plainText)
            }
        }
    }

}
