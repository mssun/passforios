//
//  UtilsExtension.swift
//  pass
//
//  Created by Yishi Lin on 13/6/17.
//  Copyright © 2017年 Bob Sun. All rights reserved.
//

import Foundation
import passKit
import SVProgressHUD

extension Utils {
    static func alert(title: String, message: String, controller: UIViewController, handler: ((UIAlertAction) -> Void)? = nil, completion: (() -> Void)? = nil) {
        SVProgressHUD.dismiss()
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "Ok".localize(), style: UIAlertAction.Style.default, handler: handler))
        controller.present(alert, animated: true, completion: completion)
    }
}
