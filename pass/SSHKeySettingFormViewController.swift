//
//  SSHKeySettingFormViewController.swift
//  pass
//
//  Created by Mingshen Sun on 24/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Former

class SSHKeySettingFormViewController: FormViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let publicKeyURLTextFieldRow = TextFieldRowFormer<TextFieldTableViewCell>(instantiateType: .Nib(nibName: "TextFieldTableViewCell")) { (row: TextFieldTableViewCell) -> Void in
            row.titleLabel.text = "SSH Public Key URL"
            }.configure { (row) in
                row.rowHeight = 52
        }
        let privateKeyURLTextFieldRow = TextFieldRowFormer<TextFieldTableViewCell>(instantiateType: .Nib(nibName: "TextFieldTableViewCell")) { (row: TextFieldTableViewCell) -> Void in
            row.titleLabel.text = "SSH Private Key URL"
        }.configure { (row) in
            row.rowHeight = 52
        }
        
        let privateKeyPhassphraseTextFieldRow = TextFieldRowFormer<TextFieldTableViewCell>(instantiateType: .Nib(nibName: "TextFieldTableViewCell")) { (row: TextFieldTableViewCell) -> Void in
            row.titleLabel.text = "Phassphrase"
            row.textField.isSecureTextEntry = true
            }.configure { (row) in
                row.rowHeight = 52
        }
        former.append(sectionFormer: SectionFormer(rowFormer: publicKeyURLTextFieldRow, privateKeyURLTextFieldRow, privateKeyPhassphraseTextFieldRow))
    }
}
