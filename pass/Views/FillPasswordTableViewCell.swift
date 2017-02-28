//
//  FillPasswordTableViewCell.swift
//  pass
//
//  Created by Mingshen Sun on 11/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit

class FillPasswordTableViewCell: ContentTableViewCell {

    @IBOutlet weak var contentTextField: UITextField!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    @IBAction func generatePassword(_ sender: UIButton) {
        let plainPassword = Utils.randomString(length: 16)
        contentTextField.attributedText = Utils.attributedPassword(plainPassword: plainPassword)
        Utils.copyToPasteboard(textToCopy: plainPassword)
    }
    
    override func getContent() -> String? {
        return contentTextField.attributedText?.string
    }
    
    override func setContent(content: String) {
        contentTextField.attributedText = Utils.attributedPassword(plainPassword: content)
    }
}
