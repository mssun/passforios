//
//  UIAlertActionExtension.swift
//  passKit
//
//  Created by Sun, Mingshen on 4/17/20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import UIKit
import Foundation

extension UIAlertAction {
    public static func cancelAndPopView(controller: UIViewController) -> UIAlertAction {
        return cancel() { _ in
            controller.navigationController?.popViewController(animated: true)
        }
    }

    public static func cancel(handler: ((UIAlertAction) -> Void)? = nil) -> UIAlertAction {
        cancel(with: "Cancel", handler: handler)
    }

    public static func dismiss(handler: ((UIAlertAction) -> Void)? = nil) -> UIAlertAction {
        cancel(with: "Dismiss", handler: handler)
    }

    public static func cancel(with title: String, handler: ((UIAlertAction) -> Void)? = nil) -> UIAlertAction {
        UIAlertAction(title: "Cancel".localize(), style: .cancel, handler: handler)
    }

    public static func ok(handler: ((UIAlertAction) -> Void)? = nil) -> UIAlertAction {
        UIAlertAction(title: "Ok".localize(), style: .default, handler: handler)
    }

    public static func okAndPopView(controller: UIViewController) -> UIAlertAction {
        return ok() { _ in
            controller.navigationController?.popViewController(animated: true)
        }
    }

    public static func selectKey(controller: UIViewController, handler: ((UIAlertAction) -> Void)?) -> UIAlertAction {
        UIAlertAction(title: "Select Key", style: .default) { _ in
            let selectKeyAlert = UIAlertController(title: "Select from imported keys", message: nil, preferredStyle: .actionSheet)
            try? PGPAgent.shared.getShortKeyID().forEach({ k in
                let action = UIAlertAction(title: k, style: .default, handler: handler)
                selectKeyAlert.addAction(action)
            })
            selectKeyAlert.addAction(UIAlertAction.cancelAndPopView(controller: controller))
            controller.present(selectKeyAlert, animated: true, completion: nil)
        }
    }

}
