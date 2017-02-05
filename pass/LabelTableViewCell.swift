//
//  LabelTableViewCell.swift
//  pass
//
//  Created by Mingshen Sun on 2/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit


struct LabelTableViewCellData {
    var title: String
    var content: String
}

class LabelTableViewCell: UITableViewCell {

    @IBOutlet weak var contentLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!

    
    var cellData: LabelTableViewCellData? {
        didSet {
            titleLabel.text = cellData?.title
            contentLabel.text = cellData?.content
        }
    }
    
    override var canBecomeFirstResponder: Bool {
        get {
            return true
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return action == #selector(copy(_:))
    }
    override func copy(_ sender: Any?) {
        UIPasteboard.general.string = contentLabel.text
    }
    
}
