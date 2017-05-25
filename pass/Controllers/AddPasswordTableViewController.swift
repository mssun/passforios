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
    var tempContent: String = ""
    let passwordStore = PasswordStore.shared

    override func viewDidLoad() {
        tableData = [
            [[.type: PasswordEditorCellType.nameCell, .title: "name"]],
            [[.type: PasswordEditorCellType.fillPasswordCell, .title: "password"]],
            [[.type: PasswordEditorCellType.additionsCell, .title: "additions"]],
            [[.type: PasswordEditorCellType.scanQRCodeCell]]
        ]
        if let lengthSetting = Globals.passwordDefaultLength[Defaults[.passwordGeneratorFlavor]],
            lengthSetting.max > lengthSetting.min {
            tableData[1].append([.type: PasswordEditorCellType.passwordLengthCell, .title: "passwordlength"])
        }
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
            guard nameCell?.getContent()?.isEmpty == false else {
                let alertTitle = "Cannot Add Password"
                let alertMessage = "Please fill in the name."
                Utils.alert(title: alertTitle, message: alertMessage, controller: self, completion: nil)
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
            let encodedName = (nameCell?.getContent()?.stringByAddingPercentEncodingForRFC3986())!
            let name = URL(string: encodedName)!.lastPathComponent
            let url = URL(string: encodedName)!.appendingPathExtension("gpg")
            password = Password(name: name, url: url, plainText: plainText)
        }
    }
}
