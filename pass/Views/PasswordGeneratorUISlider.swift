//
//  PasswordGeneratorUISlider.swift
//

import UIKit

class PasswordGeneratorUISlider: UISlider {
    override func draw(_: CGRect) {
        transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
    }
}
