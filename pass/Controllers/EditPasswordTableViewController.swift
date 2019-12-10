//
//  EditPasswordTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 12/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import passKit

class EditPasswordTableViewController: PasswordEditorTableViewController {
    override func viewDidLoad() {
        tableData = [
            [[.type: PasswordEditorCellType.nameCell, .title: "Name".localize(), .content: password!.namePath]],
            [[.type: PasswordEditorCellType.fillPasswordCell, .title: "Password".localize(), .content: password!.password]],
            [[.type: PasswordEditorCellType.additionsCell, .title: "Additions".localize(), .content: password!.additionsPlainText]],
            [[.type: PasswordEditorCellType.scanQRCodeCell],
             [.type: PasswordEditorCellType.deletePasswordCell]]
        ]
        if PasswordGeneratorFlavour.from(SharedDefaults[.passwordGeneratorFlavor]) == .RANDOM {
            tableData[1].append([.type: PasswordEditorCellType.passwordLengthCell, .title: "passwordlength"])
        }
        tableData[1].append([.type: PasswordEditorCellType.memorablePasswordGeneratorCell])
        super.viewDidLoad()
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "saveEditPasswordSegue" {
            // check name
            guard checkName() == true else {
                return false
            }
        }
        return true
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if segue.identifier == "saveEditPasswordSegue" {
            let editedPlainText = plainText
            let (name, url) = getNameURL()
            if password!.plainText != editedPlainText || password!.url.path != url.path {
                password!.updatePassword(name: name, url: url, plainText: editedPlainText)
            }
        }
    }
}
