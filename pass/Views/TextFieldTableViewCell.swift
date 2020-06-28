//
//  TextFieldTableViewCell.swift
//  pass
//
//  Created by Mingshen Sun on 10/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit

class TextFieldTableViewCell: UITableViewCell, ContentProvider {
    @IBOutlet var contentTextField: UITextField!

    func getContent() -> String? {
        contentTextField.text
    }

    func setContent(content: String?) {
        contentTextField.text = content
    }
}
