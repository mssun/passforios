//
//  TextFieldTableViewCell.swift
//  pass
//
//  Created by Mingshen Sun on 10/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit

class TextFieldTableViewCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var contentTextField: UITextField!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        titleLabel.isUserInteractionEnabled = true
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tap(_:)))
        titleLabel.addGestureRecognizer(tapGestureRecognizer)
    }
    
    func tap(_ sender: Any?) {
        contentTextField.becomeFirstResponder()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
}
