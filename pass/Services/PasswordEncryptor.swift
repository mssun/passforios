//
//  PasswordEncryptor.swift
//  pass
//
//  Created by Mingshen Sun on 17/1/2021.
//  Copyright © 2021 Bob Sun. All rights reserved.
//

import passKit

func encryptPassword(in controller: UIViewController, with password: Password, keyID: String? = nil, completion: @escaping (() -> Void)) {
    DispatchQueue.global(qos: .userInitiated).async {
        do {
            _ = try PasswordStore.shared.add(password: password, keyID: keyID)
            DispatchQueue.main.async {
                completion()
            }
        } catch let AppError.pgpPublicKeyNotFound(keyID: key) {
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "Cannot Encrypt Password", message: AppError.pgpPublicKeyNotFound(keyID: key).localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction.cancelAndPopView(controller: controller))
                let selectKey = UIAlertAction.selectKey(controller: controller) { action in
                    encryptPassword(in: controller, with: password, keyID: action.title, completion: completion)
                }
                alert.addAction(selectKey)

                controller.present(alert, animated: true)
            }
            return
        } catch {
            DispatchQueue.main.async {
                Utils.alert(title: "Error".localize(), message: error.localizedDescription, controller: controller, completion: nil)
            }
        }
    }
}
