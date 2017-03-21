//
//  FillPasswordTableViewCell.swift
//  pass
//
//  Created by Mingshen Sun on 11/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit

protocol FillPasswordTableViewCellDelegate {
    func generatePassword() -> String
}

class FillPasswordTableViewCell: ContentTableViewCell {

    @IBOutlet weak var contentTextField: UITextField!
    var delegate: FillPasswordTableViewCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        contentTextField.font = UIFont(name: Globals.passwordFonts, size: (contentTextField.font?.pointSize)!)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    @IBAction func generatePassword(_ sender: UIButton) {
        let plainPassword = self.delegate?.generatePassword() ?? Utils.generatePassword(length: 16)
        self.setContent(content: plainPassword)
        Utils.copyToPasteboard(textToCopy: plainPassword)
    }
    
    override func getContent() -> String? {
        return contentTextField.attributedText?.string
    }
    
    override func setContent(content: String?) {
        contentTextField.attributedText = Utils.attributedPassword(plainPassword: content ?? "")
    }
}
