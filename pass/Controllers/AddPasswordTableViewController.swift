//
//  AddPasswordTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 10/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import passKit
import UIKit

class AddPasswordTableViewController: PasswordEditorTableViewController {
    var defaultDirPrefix = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        tableData[0][0][PasswordEditorCellKey.content] = defaultDirPrefix
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender _: Any?) -> Bool {
        if identifier == "saveAddPasswordSegue" {
            // check PGP key
            guard PGPAgent.shared.isPrepared else {
                let alertTitle = "CannotAddPassword".localize()
                let alertMessage = "PgpKeyNotSet.".localize()
                Utils.alert(title: alertTitle, message: alertMessage, controller: self, completion: nil)
                return false
            }

            // check name
            guard checkName() else {
                return false
            }
        }
        return true
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if segue.identifier == "saveAddPasswordSegue" {
            let (name, url) = getNameURL()
            password = Password(name: name, url: url, plainText: plainText)
        }
    }
}
