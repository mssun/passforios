//
//  AddPasswordTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 10/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import passKit

class AddPasswordTableViewController: PasswordEditorTableViewController {
    let passwordStore = PasswordStore.shared
    var defaultDirPrefix = ""

    override func viewDidLoad() {
        tableData = [
            [[.type: PasswordEditorCellType.nameCell, .title: "name"]],
            [[.type: PasswordEditorCellType.fillPasswordCell, .title: "password"]],
            [[.type: PasswordEditorCellType.additionsCell, .title: "additions"]],
            [[.type: PasswordEditorCellType.scanQRCodeCell]]
        ]
        if PasswordGeneratorFlavour.from(SharedDefaults[.passwordGeneratorFlavor]) == .RANDOM {
            tableData[1].append([.type: PasswordEditorCellType.passwordLengthCell, .title: "passwordlength"])
        }
        tableData[1].append([.type: PasswordEditorCellType.memorablePasswordGeneratorCell])
        tableData[0][0][PasswordEditorCellKey.content] = defaultDirPrefix
        super.viewDidLoad()
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "saveAddPasswordSegue" {
            // check PGP key
            guard passwordStore.privateKey != nil else {
                let alertTitle = "Cannot Add Password"
                let alertMessage = "PGP Key is not set. Please set your PGP Key first."
                Utils.alert(title: alertTitle, message: alertMessage, controller: self, completion: nil)
                return false
            }

            // check name
            guard checkName() == true else {
                return false
            }
        }
        return true
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if segue.identifier == "saveAddPasswordSegue" {
            var plainText = (fillPasswordCell?.getContent())!
            if let additionsString = additionsCell?.getContent(), additionsString.isEmpty == false {
                plainText.append("\n")
                plainText.append(additionsString)
            }
            let (name, url) = getNameURL()
            password = Password(name: name, url: url, plainText: plainText)
        }
    }
}
