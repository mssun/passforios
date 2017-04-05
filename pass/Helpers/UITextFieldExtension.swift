//
//  UIViewControllerExtionsion.swift
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
            return objc_getAssociatedObject(self, &kAssociationKeyNextField) as? UITextField
        }
        set(newField) {
            objc_setAssociatedObject(self, &kAssociationKeyNextField, newField, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}

extension UIViewController {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.nextField != nil {
            textField.nextField?.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return true
    }
}
