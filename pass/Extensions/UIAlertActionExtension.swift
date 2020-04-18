//
//  UIAlertActionExtension.swift
//  passKit
//
//  Created by Sun, Mingshen on 4/17/20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import UIKit
import Foundation
import passKit

extension UIAlertAction {
    static func cancelAndPopView(controller: UIViewController) -> UIAlertAction {
        UIAlertAction(title: "Cancel".localize(), style: .cancel) { _ in
            controller.navigationController?.popViewController(animated: true)
        }
    }

    static func cancel() -> UIAlertAction {
        cancel(with: "Cancel")
    }

    static func dismiss() -> UIAlertAction {
        cancel(with: "Dismiss")
    }

    static func cancel(with title: String) -> UIAlertAction {
        UIAlertAction(title: "Cancel".localize(), style: .cancel, handler: nil)
    }

    static func selectKey(controller: UIViewController, handler: ((UIAlertAction) -> Void)?) -> UIAlertAction {
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
