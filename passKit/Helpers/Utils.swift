//
//  Utils.swift
//  passKit
//
//  Created by Mingshen Sun on 8/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

public enum Utils {
    public static func copyToPasteboard(textToCopy: String?) {
        guard textToCopy != nil else {
            return
        }
        UIPasteboard.general.string = textToCopy
    }

    public static func attributedPassword(plainPassword: String) -> NSAttributedString {
        let attributedPassword = NSMutableAttributedString(string: plainPassword)
        // draw all digits in the password into red
        // draw all punctuation characters in the password into blue
        for (index, element) in plainPassword.unicodeScalars.enumerated() {
            var charColor = UIColor.darkText
            if NSCharacterSet.decimalDigits.contains(element) {
                charColor = Colors.systemRed
            } else if !NSCharacterSet.letters.contains(element) {
                charColor = Colors.systemBlue
            } else {
                charColor = Colors.label
            }
            attributedPassword.addAttribute(NSAttributedString.Key.foregroundColor, value: charColor, range: NSRange(location: index, length: 1))
        }
        return attributedPassword
    }

    public static func alert(title: String, message: String, controller: UIViewController, handler: ((UIAlertAction) -> Void)? = nil, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "Ok".localize(), style: UIAlertAction.Style.default, handler: handler))
        controller.present(alert, animated: true, completion: completion)
    }

    public static func createRequestPGPKeyPassphraseHandler(controller: UIViewController) -> (String) -> String {
        { keyID in
            let sem = DispatchSemaphore(value: 0)
            var passphrase = ""
            DispatchQueue.main.async {
                var title: String!
                if keyID.isEmpty {
                    title = "Passphrase".localize()
                } else {
                    title = "Passphrase".localize() + " (\(keyID.suffix(8)))"
                }
                let message = "FillInPgpPassphrase.".localize()
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alert.addAction(
                    UIAlertAction.ok { _ in
                        passphrase = alert.textFields?.first?.text ?? ""
                        sem.signal()
                    }
                )
                alert.addTextField { textField in
                    textField.text = AppKeychain.shared.get(for: AppKeychain.getPGPKeyPassphraseKey(keyID: keyID)) ?? ""
                    textField.isSecureTextEntry = true
                }
                controller.present(alert, animated: true)
            }
            _ = sem.wait(timeout: DispatchTime.distantFuture)
            if Defaults.isRememberPGPPassphraseOn {
                AppKeychain.shared.add(string: passphrase, for: AppKeychain.getPGPKeyPassphraseKey(keyID: keyID))
            }
            return passphrase
        }
    }
}
