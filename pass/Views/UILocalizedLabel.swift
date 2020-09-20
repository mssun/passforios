//
//  UILocalizedLabel.swift
//  pass
//
//  Created by Danny Moesch on 20.01.19.
//  Copyright © 2019 Bob Sun. All rights reserved.
//

import passKit
import UIKit

class UILocalizedLabel: UILabel {
    override func awakeFromNib() {
        super.awakeFromNib()
        text = text?.localize()
    }
}
