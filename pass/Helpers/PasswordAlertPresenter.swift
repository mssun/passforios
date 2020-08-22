//
//  PasswordAlertPresenter.swift
//  pass
//
//  Created by Danny Moesch on 23.08.20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import SVProgressHUD

protocol PasswordAlertPresenter {
    func present(message: String, lastPassword: String?) -> String?
}

extension PasswordAlertPresenter where Self: UIViewController {
    func present(message: String, lastPassword: String?) -> String? {
        let sem = DispatchSemaphore(value: 0)
        var password: String?

        DispatchQueue.main.async {
            SVProgressHUD.dismiss()
            let alert = UIAlertController(title: "Password".localize(), message: message, preferredStyle: .alert)
            alert.addTextField {
                $0.text = lastPassword ?? ""
                $0.isSecureTextEntry = true
            }
            alert.addAction(
                .ok { _ in
                    password = alert.textFields?.first?.text
                    sem.signal()
                }
            )
            alert.addAction(
                .cancel { _ in
                    password = nil
                    sem.signal()
                }
            )
            self.present(alert, animated: true)
        }

        _ = sem.wait(timeout: .distantFuture)
        return password
    }
}
