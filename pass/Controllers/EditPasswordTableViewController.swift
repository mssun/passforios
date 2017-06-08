//
//  EditPasswordTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 12/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import SwiftyUserDefaults

class EditPasswordTableViewController: PasswordEditorTableViewController {
    override func viewDidLoad() {
        tableData = [
            [[.type: PasswordEditorCellType.nameCell, .title: "name", .content: password!.namePath]],
            [[.type: PasswordEditorCellType.fillPasswordCell, .title: "password", .content: password!.password]],
            [[.type: PasswordEditorCellType.additionsCell, .title: "additions", .content: password!.getAdditionsPlainText()]],
            [[.type: PasswordEditorCellType.scanQRCodeCell],
             [.type: PasswordEditorCellType.deletePasswordCell]]
        ]
        if let lengthSetting = Globals.passwordDefaultLength[Defaults[.passwordGeneratorFlavor]],
            lengthSetting.max > lengthSetting.min {
            tableData[1].append([.type: PasswordEditorCellType.passwordLengthCell, .title: "passwordlength"])
        }
        super.viewDidLoad()
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "saveEditPasswordSegue" {
            if let name = nameCell?.getContent(),
                let path = name.stringByAddingPercentEncodingForRFC3986(),
                let _ = URL(string: path) {
                return true
            } else {
                Utils.alert(title: "Cannot Save", message: "Password name is invalid.", controller: self, completion: nil)
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
            let encodedName = (nameCell?.getContent()?.stringByAddingPercentEncodingForRFC3986())!
            let name = URL(string: encodedName)!.lastPathComponent
            let url = URL(string: encodedName)!.appendingPathExtension("gpg")
            if password!.plainText != plainText || password!.url!.path != url.path {
                password!.updatePassword(name: name, url: url, plainText: plainText)
            }
        }
    }

}
