//
//  UICodeHighlightingLabel.swift
//  pass
//
//  Created by Danny Moesch on 20.01.19.
//  Copyright © 2019 Bob Sun. All rights reserved.
//

import passKit
import UIKit

class UICodeHighlightingLabel: UILocalizedLabel {
    private static let CODE_ATTRIBUTES: [NSAttributedString.Key: Any] = [.font: UIFont(name: "Menlo-Regular", size: 12)!]
    private static let ATTRIBUTED_NEWLINE = NSAttributedString(string: "\n")

    override func awakeFromNib() {
        super.awakeFromNib()
        guard let text = text else {
            return
        }
        attributedText = formatCode(in: text)
    }

    /// Format code sections in a multiline string block.
    ///
    /// A line in the string is interpreted as a code section if it starts with two spaces.
    ///
    /// - Parameter text: Multiline string block
    /// - Returns: Same multiline string block with code sections formatted
    private func formatCode(in text: String) -> NSMutableAttributedString {
        let formattedText = text.splitByNewline()
            .map { line -> NSAttributedString in
                if line.starts(with: "  ") {
                    return NSAttributedString(string: line, attributes: UICodeHighlightingLabel.CODE_ATTRIBUTES)
                }
                return NSAttributedString(string: line)
            }
            .reduce(into: NSMutableAttributedString(string: "")) {
                $0.append($1)
                $0.append(UICodeHighlightingLabel.ATTRIBUTED_NEWLINE)
            }
        formattedText.deleteCharacters(in: NSRange(location: formattedText.length - 1, length: 1))
        return formattedText
    }
}
