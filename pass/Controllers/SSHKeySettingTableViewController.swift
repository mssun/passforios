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

class SSHKeySettingTableViewController: AutoCellHeightUITableViewController {

    @IBOutlet weak var privateKeyURLTextField: UITextField!
    let passwordStore = PasswordStore.shared

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func doneButtonTapped(_ sender: UIButton) {
        guard let privateKeyURL = URL(string: privateKeyURLTextField.text!.trimmed) else {
            Utils.alert(title: "CannotSave".localize(), message: "SetPrivateKeyUrl.".localize(), controller: self, completion: nil)
            return
        }

        do {
            try Data(contentsOf: privateKeyURL).write(to: URL(fileURLWithPath: SshKey.PRIVATE.getFileSharingPath()), options: .atomic)
            try self.passwordStore.gitSSHKeyImportFromFileSharing()
            SharedDefaults[.gitSSHKeySource] = "file"
            SVProgressHUD.showSuccess(withStatus: "Imported".localize())
            SVProgressHUD.dismiss(withDelay: 1)
        } catch {
            Utils.alert(title: "Error".localize(), message: error.localizedDescription, controller: self, completion: nil)
        }
        SharedDefaults[.gitSSHKeySource] = "url"
        self.navigationController!.popViewController(animated: true)
    }

}
