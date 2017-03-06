//
//  SSHKeySettingTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 25/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import SwiftyUserDefaults
import SVProgressHUD

class SSHKeySettingTableViewController: UITableViewController {

    @IBOutlet weak var passphraseTextField: UITextField!
    @IBOutlet weak var privateKeyURLTextField: UITextField!
    @IBOutlet weak var publicKeyURLTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        passphraseTextField.text = Utils.getPasswordFromKeychain(name: "gitRepositorySSHPrivateKeyPassphrase") ?? ""
        privateKeyURLTextField.text = Defaults[.gitRepositorySSHPrivateKeyURL]?.absoluteString
        publicKeyURLTextField.text = Defaults[.gitRepositorySSHPublicKeyURL]?.absoluteString
        var doneBarButtonItem: UIBarButtonItem?

        doneBarButtonItem = UIBarButtonItem(title: "Done",
                                            style: UIBarButtonItemStyle.done,
                                            target: self,
                                            action: #selector(doneButtonTapped(_:)))
        navigationItem.rightBarButtonItem = doneBarButtonItem
        navigationItem.title = "SSH Key"
    }
    
    func doneButtonTapped(_ sender: UIButton) {
        guard URL(string: publicKeyURLTextField.text!) != nil else {
            Utils.alert(title: "Cannot Save", message: "Please set Public Key URL first.", controller: self, completion: nil)
            return
        }
        guard URL(string: privateKeyURLTextField.text!) != nil else {
            Utils.alert(title: "Cannot Save", message: "Please set Private Key URL first.", controller: self, completion: nil)
            return
        }
        
        Defaults[.gitRepositorySSHPublicKeyURL] = URL(string: publicKeyURLTextField.text!)
        Defaults[.gitRepositorySSHPrivateKeyURL] = URL(string: privateKeyURLTextField.text!)
        Utils.addPasswordToKeychain(name: "gitRepositorySSHPrivateKeyPassphrase", password: passphraseTextField.text!)
        
        do {
            try Data(contentsOf: Defaults[.gitRepositorySSHPublicKeyURL]!).write(to: Globals.sshPublicKeyURL, options: .atomic)
            try Data(contentsOf: Defaults[.gitRepositorySSHPrivateKeyURL]!).write(to: Globals.sshPrivateKeyURL, options: .atomic)
        } catch {
            SVProgressHUD.showError(withStatus: error.localizedDescription)
            SVProgressHUD.dismiss(withDelay: 1)
            print(error)
        }

        navigationController!.popViewController(animated: true)
    }

}
