//
//  PasswordDetailTitleTableViewCell.swift
//  pass
//
//  Created by Mingshen Sun on 6/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit

class PasswordDetailTitleTableViewCell: UITableViewCell {
    @IBOutlet var categoryLabel: UILabel!
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var passwordImageImageView: UIImageView!
    @IBOutlet var labelImageConstraint: NSLayoutConstraint!
    @IBOutlet var labelCellConstraint: NSLayoutConstraint!

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
}
