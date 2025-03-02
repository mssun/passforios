//
//  EditPasswordTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 12/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import passKit
import UIKit

class EditPasswordTableViewController: PasswordEditorTableViewController {
    override func shouldPerformSegue(withIdentifier identifier: String, sender _: Any?) -> Bool {
        if identifier == "saveEditPasswordSegue" {
            // check name
            guard checkName() else {
                return false
            }
        }
        return true
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if segue.identifier == "saveEditPasswordSegue" {
            let editedPlainText = plainText
            let (name, path) = getNamePath()
            if password!.plainText != editedPlainText || password!.path != path {
                password!.updatePassword(name: name, path: path, plainText: editedPlainText)
            }
            if let controller = segue.destination as? PasswordDetailTableViewController {
                controller.password = password
            }
        }
    }
}
