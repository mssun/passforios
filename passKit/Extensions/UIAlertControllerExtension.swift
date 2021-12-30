//
//  UIAlertControllerExtension.swift
//  passKit
//
//  Copyright © 2021 Bob Sun. All rights reserved.
//

import Foundation

public extension UIAlertController {
    class func removeConfirmationAlert(title: String, message: String, handler: ((UIAlertAction) -> Void)? = nil) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction.remove(handler: handler))
        alert.addAction(UIAlertAction.cancel())
        return alert
    }
}
