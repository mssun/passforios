//
//  SSHKeyUrlImportTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 25/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import SVProgressHUD
import passKit

class SSHKeyUrlImportTableViewController: AutoCellHeightUITableViewController {

    @IBOutlet weak var privateKeyURLTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        privateKeyURLTextField.text = Defaults.gitSSHPrivateKeyURL?.absoluteString
    }

    @IBAction func doneButtonTapped(_ sender: UIButton) {
        if getScheme(from: privateKeyURLTextField.text?.trimmed) == "http" {
            let savePassphraseAlert = UIAlertController(title: "HttpNotSecure".localize(), message: "ReallyUseHttp?".localize(), preferredStyle: .alert)
            savePassphraseAlert.addAction(UIAlertAction(title: "No".localize(), style: .default) { _ in })
            savePassphraseAlert.addAction(UIAlertAction(title: "Yes".localize(), style: .destructive) { _ in
                self.performSegue(withIdentifier: "importSSHKeySegue", sender: self)
            })
            return present(savePassphraseAlert, animated: true)
        }
        performSegue(withIdentifier: "importSSHKeySegue", sender: self)
    }

    private func getScheme(from url: String?) -> String? {
        return url.flatMap(URL.init(string:))?.scheme
    }
}

extension SSHKeyUrlImportTableViewController: KeyImporter {

    static let keySource = KeySource.url
    static let label = "DownloadFromUrl".localize()

    func isReadyToUse() -> Bool {
        guard let scheme = getScheme(from: privateKeyURLTextField.text?.trimmed) else {
            Utils.alert(title: "CannotSave".localize(), message: "SetPrivateKeyUrl.".localize(), controller: self)
            return false
        }
        guard scheme == "https" || scheme == "http" else {
            Utils.alert(title: "CannotSave".localize(), message: "UseEitherHttpsOrHttp.".localize(), controller: self)
            return false
        }
        return true
    }

    func importKeys() throws {
        Defaults.gitSSHPrivateKeyURL = URL(string: privateKeyURLTextField.text!.trimmed)

        try KeyFileManager.PrivateSsh.importKey(from: Defaults.gitSSHPrivateKeyURL!)
    }
}
