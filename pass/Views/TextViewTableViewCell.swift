//
//  TextViewTableViewCell.swift
//  pass
//
//  Created by Mingshen Sun on 11/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit

class TextViewTableViewCell: UITableViewCell, ContentProvider {

    @IBOutlet weak var contentTextView: UITextView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.contentTextView.textContainer.lineFragmentPadding = 0
        self.contentTextView.textContainerInset = .zero
    }

    func getContent() -> String? {
        return contentTextView.text
    }

    func setContent(content: String?) {
        contentTextView.text = content
    }
}
