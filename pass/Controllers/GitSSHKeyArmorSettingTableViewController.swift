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
        armorPublicKeyTextView.delegate = self
        armorPrivateKeyTextView.delegate = self
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
        Defaults[.gitSSHKeySource] = "armor"
        self.navigationController!.popViewController(animated: true)
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
