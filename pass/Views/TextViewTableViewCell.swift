//
//  TextViewTableViewCell.swift
//  pass
//
//  Created by Mingshen Sun on 11/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit

class TextViewTableViewCell: ContentTableViewCell {

    @IBOutlet weak var contentTextView: UITextView!
    override func awakeFromNib() {
        super.awakeFromNib()
        self.contentTextView.textContainer.lineFragmentPadding = 0
        self.contentTextView.textContainerInset = .zero
    }
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    override func getContent() -> String? {
        return contentTextView.text
    }
    
    override func setContent(content: String?) {
        contentTextView.text = content
    }
}
