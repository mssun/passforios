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
            [[.type: PasswordEditorCellType.nameCell, .title: "name", .content: password!.namePath]],
            [[.type: PasswordEditorCellType.fillPasswordCell, .title: "password", .content: password!.password]],
            [[.type: PasswordEditorCellType.additionsCell, .title: "additions", .content: password!.additionsPlainText]],
            [[.type: PasswordEditorCellType.scanQRCodeCell],
             [.type: PasswordEditorCellType.deletePasswordCell]]
        ]
        if PasswordGeneratorFlavour.from(SharedDefaults[.passwordGeneratorFlavor]) == PasswordGeneratorFlavour.RANDOM {
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
            var plainText = (fillPasswordCell?.getContent())!
            if let additionsString = additionsCell?.getContent(), additionsString.isEmpty == false {
                plainText.append("\n")
                plainText.append(additionsString)
            }
            let (name, url) = getNameURL()
            if password!.plainText != plainText || password!.url.path != url.path {
                password!.updatePassword(name: name, url: url, plainText: plainText)
            }
        }
    }

}
