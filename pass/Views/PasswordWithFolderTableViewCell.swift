//
//  PasswordTableViewCell.swift
//  pass
//
//  Created by Mingshen Sun on 8/3/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit

class PasswordWithFolderTableViewCell: UITableViewCell {

    @IBOutlet weak var passwordLabel: UILabel!
    @IBOutlet weak var folderLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
