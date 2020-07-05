//
//  SSHKeyUrlImportTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 25/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import passKit
import SVProgressHUD

class SSHKeyUrlImportTableViewController: AutoCellHeightUITableViewController {
    @IBOutlet var privateKeyURLTextField: UITextField!

    var sshPrivateKeyURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        privateKeyURLTextField.text = Defaults.gitSSHPrivateKeyURL?.absoluteString
    }

    @IBAction
    private func doneButtonTapped(_: UIButton) {
        guard let text = privateKeyURLTextField.text,
            let privateKeyURL = URL(string: text) else {
            Utils.alert(title: "CannotSave".localize(), message: "SetPrivateKeyUrl.".localize(), controller: self)
            return
        }

        if privateKeyURL.scheme?.lowercased() == "http" {
            let savePassphraseAlert = UIAlertController(title: "HttpNotSecure".localize(), message: "ReallyUseHttp?".localize(), preferredStyle: .alert)
            savePassphraseAlert.addAction(UIAlertAction(title: "No".localize(), style: .default) { _ in })
            savePassphraseAlert.addAction(
                UIAlertAction(title: "Yes".localize(), style: .destructive) { _ in
                    self.performSegue(withIdentifier: "importSSHKeySegue", sender: self)
                }
            )
            return present(savePassphraseAlert, animated: true)
        }
        sshPrivateKeyURL = privateKeyURL
        performSegue(withIdentifier: "importSSHKeySegue", sender: self)
    }
}

extension SSHKeyUrlImportTableViewController: KeyImporter {
    static let keySource = KeySource.url
    static let label = "DownloadFromUrl".localize()

    func isReadyToUse() -> Bool {
        guard let url = sshPrivateKeyURL else {
            Utils.alert(title: "CannotSave".localize(), message: "SetPrivateKeyUrl.".localize(), controller: self)
            return false
        }
        guard url.scheme == "https" || url.scheme == "http" else {
            Utils.alert(title: "CannotSave".localize(), message: "UseEitherHttpsOrHttp.".localize(), controller: self)
            return false
        }
        return true
    }

    func importKeys() throws {
        Defaults.gitSSHPrivateKeyURL = sshPrivateKeyURL
        try KeyFileManager.PrivateSsh.importKey(from: Defaults.gitSSHPrivateKeyURL!)
    }
}
