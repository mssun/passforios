//
//  UIViewControllerExtension.swift
//  pass
//
//  Created by Yishi Lin on 5/4/17.
//  Copyright © 2017 Yishi Lin. All rights reserved.
//

public extension UIViewController {
    @objc
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.nextField != nil {
            textField.nextField?.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return true
    }
}
