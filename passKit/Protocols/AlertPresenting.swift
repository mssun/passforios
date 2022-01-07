//
//  AlertPresenting.swift
//  pass
//
//  Copyright © 2022 Bob Sun. All rights reserved.
//

import UIKit

public typealias AlertAction = (UIAlertAction) -> Void

public protocol AlertPresenting {
    func presentAlert(title: String, message: String)
    func presentFailureAlert(message: String, action: AlertAction?)
    func presentAlertWithAction(title: String, message: String, action: AlertAction?)
}

public extension AlertPresenting where Self: UIViewController {
    func presentAlert(title: String, message: String) {
        presentAlert(
            title: title,
            message: message,
            actions: [UIAlertAction(title: "OK", style: .cancel, handler: nil)]
        )
    }

    func presentFailureAlert(message: String, action: AlertAction?) {
        presentAlert(
            title: "Error",
            message: message,
            actions: [UIAlertAction(title: "OK", style: .destructive, handler: action)]
        )
    }

    func presentAlertWithAction(title: String, message: String, action: AlertAction?) {
        presentAlert(
            title: title,
            message: message,
            actions: [
                UIAlertAction(title: "Yes", style: .default, handler: action),
                UIAlertAction(title: "No", style: .cancel, handler: nil),
            ]
        )
    }

    private func presentAlert(title: String, message: String, actions: [UIAlertAction] = []) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        actions.forEach { action in
            alertController.addAction(action)
        }
        present(alertController, animated: true, completion: nil)
    }
}
