//
//  SSHKeySettingTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 25/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import SVProgressHUD
import passKit

class SSHKeySettingTableViewController: UITableViewController {

    @IBOutlet weak var privateKeyURLTextField: UITextField!
    let passwordStore = PasswordStore.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        privateKeyURLTextField.text = SharedDefaults[.gitSSHPrivateKeyURL]?.absoluteString
    }
    
    
    @IBAction func doneButtonTapped(_ sender: UIButton) {
        guard let privateKeyURL = URL(string: privateKeyURLTextField.text!) else {
            Utils.alert(title: "Cannot Save", message: "Please set Private Key URL first.", controller: self, completion: nil)
            return
        }
        
        SharedDefaults[.gitSSHPrivateKeyURL] = privateKeyURL
        
        do {
            try Data(contentsOf: privateKeyURL).write(to: URL(fileURLWithPath: Globals.gitSSHPrivateKeyPath), options: .atomic)
        } catch {
            Utils.alert(title: "Error", message: error.localizedDescription, controller: self, completion: nil)
        }
        SharedDefaults[.gitSSHKeySource] = "url"
        self.navigationController!.popViewController(animated: true)
    }

}
