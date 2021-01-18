//
//  PasswordDecryptor.swift
//  pass
//
//  Created by Sun, Mingshen on 1/17/21.
//  Copyright © 2021 Bob Sun. All rights reserved.
//

import passKit
import SVProgressHUD
import UIKit

func decryptPassword(in controller: UIViewController, with passwordPath: String, using keyID: String? = nil, completion: @escaping ((Password) -> Void)) {
    DispatchQueue.global(qos: .userInteractive).async {
        do {
            let requestPGPKeyPassphrase = Utils.createRequestPGPKeyPassphraseHandler(controller: controller)
            let decryptedPassword = try PasswordStore.shared.decrypt(path: passwordPath, keyID: keyID, requestPGPKeyPassphrase: requestPGPKeyPassphrase)

            DispatchQueue.main.async {
                completion(decryptedPassword)
            }
        } catch let AppError.pgpPrivateKeyNotFound(keyID: key) {
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "CannotShowPassword".localize(), message: AppError.pgpPrivateKeyNotFound(keyID: key).localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction.cancelAndPopView(controller: controller))
                let selectKey = UIAlertAction.selectKey(controller: controller) { action in
                    decryptPassword(in: controller, with: passwordPath, using: action.title, completion: completion)
                }
                alert.addAction(selectKey)

                controller.present(alert, animated: true)
            }
        } catch {
            DispatchQueue.main.async {
                Utils.alert(title: "CannotCopyPassword".localize(), message: error.localizedDescription, controller: controller)
            }
        }
    }
}
