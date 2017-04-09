//
//  PGPKeyArmorSettingTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 17/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import SwiftyUserDefaults

class PGPKeyArmorSettingTableViewController: UITableViewController, UITextViewDelegate {
    @IBOutlet weak var armorPublicKeyTextView: UITextView!
    @IBOutlet weak var armorPrivateKeyTextView: UITextView!
    var pgpPassphrase: String?
    let passwordStore = PasswordStore.shared
    
    private var recentPastedText = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        armorPublicKeyTextView.text = Defaults[.pgpPublicKeyArmor]
        armorPrivateKeyTextView.text = Defaults[.pgpPrivateKeyArmor]
        pgpPassphrase = passwordStore.pgpKeyPassphrase
    }
    
    private func createSavePassphraseAndSegueAlert() -> UIAlertController {
        let savePassphraseAlert = UIAlertController(title: "Passphrase", message: "Do you want to save the passphrase for later decryption?", preferredStyle: UIAlertControllerStyle.alert)
        savePassphraseAlert.addAction(UIAlertAction(title: "No", style: UIAlertActionStyle.default) { _ in
            Defaults[.isRememberPassphraseOn] = false
            self.performSegue(withIdentifier: "savePGPKeySegue", sender: self)
        })
        savePassphraseAlert.addAction(UIAlertAction(title: "Save", style: UIAlertActionStyle.destructive) {_ in
            Defaults[.isRememberPassphraseOn] = true
            self.performSegue(withIdentifier: "savePGPKeySegue", sender: self)
        })
        return savePassphraseAlert
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "savePGPKeySegue" {
            if armorPublicKeyTextView.text.isEmpty {
                Utils.alert(title: "Cannot Save", message: "Please set public key first.", controller: self, completion: nil)
                return false
            }
            if armorPrivateKeyTextView.text.isEmpty {
                Utils.alert(title: "Cannot Save", message: "Please set private key first.", controller: self, completion: nil)
                return false
            }
        }
        return true
    }
    
    @IBAction func save(_ sender: Any) {
        let alert = UIAlertController(title: "Passphrase", message: "Please fill in the passphrase of your PGP secret key.", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {_ in
            self.pgpPassphrase = alert.textFields?.first?.text
            let savePassphraseAndSegueAlert = self.createSavePassphraseAndSegueAlert()
            self.present(savePassphraseAndSegueAlert, animated: true, completion: nil)
        }))
        alert.addTextField(configurationHandler: {(textField: UITextField!) in
            textField.text = self.pgpPassphrase
            textField.isSecureTextEntry = true
        })
        self.present(alert, animated: true, completion: nil)
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == UIPasteboard.general.string {
            // user pastes something, get ready to clear in 10s
            recentPastedText = text
            DispatchQueue.global(qos: .background).asyncAfter(deadline: DispatchTime.now() + 10) { [weak weakSelf = self] in
                if let pasteboardString = UIPasteboard.general.string,
                    pasteboardString == weakSelf?.recentPastedText {
                    UIPasteboard.general.string = ""
                }
            }
        }
        return true
    }
}
