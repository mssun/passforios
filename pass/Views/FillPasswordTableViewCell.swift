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
        contentTextField.text = Utils.randomString(length: 16)
    }
    
    override func getContent() -> String? {
        return contentTextField.text
    }
    
    override func setContent(content: String) {
        contentTextField.text = content
    }
}
