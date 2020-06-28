//
//  UITextFieldExtension.swift
//  pass
//
//  Created by Yishi Lin on 5/4/17.
//  Copyright © 2017 Yishi Lin. All rights reserved.
//

import Foundation
import UIKit

private var kAssociationKeyNextField: UInt8 = 0

extension UITextField {
    @IBOutlet var nextField: UITextField? {
        get {
            objc_getAssociatedObject(self, &kAssociationKeyNextField) as? UITextField
        }
        set(newField) {
            objc_setAssociatedObject(self, &kAssociationKeyNextField, newField, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    func shake() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        animation.repeatCount = 3
        animation.duration = 0.2 / TimeInterval(animation.repeatCount)
        animation.autoreverses = true
        animation.values = [3, -3]
        layer.add(animation, forKey: "shake")
    }
}
