//
//  GitSSHKeyArmorSettingTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 2/4/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import SwiftyUserDefaults

class GitSSHKeyArmorSettingTableViewController: UITableViewController, UITextViewDelegate {
    @IBOutlet weak var armorPublicKeyTextView: UITextView!
    @IBOutlet weak var armorPrivateKeyTextView: UITextView!
    var gitSSHPrivateKeyPassphrase: String?
    let passwordStore = PasswordStore.shared
    
    private var recentPastedText = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        armorPublicKeyTextView.text = Defaults[.gitSSHPublicKeyArmor]
        armorPrivateKeyTextView.text = Defaults[.gitSSHPrivateKeyArmor]
        gitSSHPrivateKeyPassphrase = passwordStore.gitSSHPrivateKeyPassphrase
        
        armorPublicKeyTextView.delegate = self
        armorPrivateKeyTextView.delegate = self
    }
    
    private func createSavePassphraseAlert() -> UIAlertController {
        let savePassphraseAlert = UIAlertController(title: "Passphrase", message: "Do you want to save the passphrase for later sync?", preferredStyle: UIAlertControllerStyle.alert)
        savePassphraseAlert.addAction(UIAlertAction(title: "No", style: UIAlertActionStyle.default) { _ in
            Defaults[.isRememberPassphraseOn] = false
            Defaults[.gitSSHKeySource] = "armor"
            self.navigationController!.popViewController(animated: true)
        })
        savePassphraseAlert.addAction(UIAlertAction(title: "Save", style: UIAlertActionStyle.destructive) {_ in
            Defaults[.isRememberPassphraseOn] = true
            self.passwordStore.gitSSHPrivateKeyPassphrase = self.gitSSHPrivateKeyPassphrase
            Defaults[.gitSSHKeySource] = "armor"
            self.navigationController!.popViewController(animated: true)
        })
        return savePassphraseAlert
    }
    
    @IBAction func doneButtonTapped(_ sender: Any) {
        Defaults[.gitSSHPublicKeyArmor] = armorPublicKeyTextView.text
        Defaults[.gitSSHPrivateKeyArmor] = armorPrivateKeyTextView.text
        do {
            try passwordStore.initGitSSHKey(with: armorPublicKeyTextView.text, .public)
            try passwordStore.initGitSSHKey(with: armorPrivateKeyTextView.text, .secret)
        } catch {
            Utils.alert(title: "Cannot Save", message: "Cannot Save SSH Key", controller: self, completion: nil)
        }
        let alert = UIAlertController(title: "Passphrase", message: "Please fill in the passphrase of your SSH secret key.", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {_ in
            self.gitSSHPrivateKeyPassphrase = alert.textFields?.first?.text
            let savePassphraseAlert = self.createSavePassphraseAlert()
            self.present(savePassphraseAlert, animated: true, completion: nil)
        }))
        alert.addTextField(configurationHandler: {(textField: UITextField!) in
            textField.text = self.gitSSHPrivateKeyPassphrase
            textField.isSecureTextEntry = true
        })
        self.present(alert, animated: true, completion: nil)
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == UIPasteboard.general.string {
            // user pastes somethint, get ready to clear in 10s
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
