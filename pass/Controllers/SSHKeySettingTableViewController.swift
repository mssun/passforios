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

    @IBOutlet weak var privateKeyURLTextField: UITextField!
    let passwordStore = PasswordStore.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        privateKeyURLTextField.text = Defaults[.gitSSHPrivateKeyURL]?.absoluteString
    }
    
    
    @IBAction func doneButtonTapped(_ sender: UIButton) {
        guard let privateKeyURL = URL(string: privateKeyURLTextField.text!) else {
            Utils.alert(title: "Cannot Save", message: "Please set Private Key URL first.", controller: self, completion: nil)
            return
        }
        
        Defaults[.gitSSHPrivateKeyURL] = privateKeyURL
        
        do {
            try Data(contentsOf: privateKeyURL).write(to: URL(fileURLWithPath: Globals.gitSSHPrivateKeyPath), options: .atomic)
        } catch {
            Utils.alert(title: "Error", message: error.localizedDescription, controller: self, completion: nil)
        }
        Defaults[.gitSSHKeySource] = "url"
        self.navigationController!.popViewController(animated: true)
    }

}
