//
//  UIAlertActionExtension.swift
//  passKit
//
//  Created by Sun, Mingshen on 4/17/20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import Foundation
import UIKit

public extension UIAlertAction {
    static func cancelAndPopView(controller: UIViewController) -> UIAlertAction {
        cancel { _ in
            controller.navigationController?.popViewController(animated: true)
        }
    }

    static func cancel(title: String = "Cancel".localize(), handler: ((UIAlertAction) -> Void)? = nil) -> UIAlertAction {
        UIAlertAction(title: title, style: .cancel, handler: handler)
    }

    static func dismiss(handler: ((UIAlertAction) -> Void)? = nil) -> UIAlertAction {
        cancel(title: "Dismiss".localize(), handler: handler)
    }

    static func ok(handler: ((UIAlertAction) -> Void)? = nil) -> UIAlertAction {
        UIAlertAction(title: "Ok".localize(), style: .default, handler: handler)
    }

    static func remove(handler: ((UIAlertAction) -> Void)? = nil) -> UIAlertAction {
        UIAlertAction(title: "Remove".localize(), style: .destructive, handler: handler)
    }

    static func okAndPopView(controller: UIViewController) -> UIAlertAction {
        ok { _ in
            controller.navigationController?.popViewController(animated: true)
        }
    }

    static func selectKey(controller: UIViewController, handler: ((UIAlertAction) -> Void)?) -> UIAlertAction {
        UIAlertAction(title: "Select Key", style: .default) { _ in
            let selectKeyAlert = UIAlertController(title: "Select from imported keys", message: nil, preferredStyle: .actionSheet)
            try? PGPAgent.shared.getShortKeyID().forEach { keyID in
                let action = UIAlertAction(title: keyID, style: .default, handler: handler)
                selectKeyAlert.addAction(action)
            }
            selectKeyAlert.addAction(Self.cancelAndPopView(controller: controller))
            controller.present(selectKeyAlert, animated: true, completion: nil)
        }
    }
}
