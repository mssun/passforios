//
//  PasswordDecryptor.swift
//  passAutoFillExtension
//
//  Created by Sun, Mingshen on 12/31/20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import UIKit
import passKit

func decryptPassword(in controller: UIViewController, with passwordPath: String, using keyID: String? = nil, completion: @escaping ((Password) -> Void)) {
    do {
        let requestPGPKeyPassphrase = Utils.createRequestPGPKeyPassphraseHandler(controller: controller)
        let decryptedPassword = try PasswordStore.shared.decrypt(path: passwordPath, keyID: keyID, requestPGPKeyPassphrase: requestPGPKeyPassphrase)

        completion(decryptedPassword)
    } catch let AppError.pgpPrivateKeyNotFound(keyID: key) {
        let alert = UIAlertController(title: "CannotShowPassword".localize(), message: AppError.pgpPrivateKeyNotFound(keyID: key).localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction.cancelAndPopView(controller: controller))
        let selectKey = UIAlertAction.selectKey(controller: controller) { action in
            decryptPassword(in: controller, with: passwordPath, using: action.title, completion: completion)
        }
        alert.addAction(selectKey)

        controller.present(alert, animated: true)
    } catch {
        Utils.alert(title: "CannotCopyPassword".localize(), message: error.localizedDescription, controller: controller)
    }
}
