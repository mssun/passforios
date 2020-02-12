//
//  PGPKeyUrlImportTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 21/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import passKit

class PGPKeyUrlImportTableViewController: AutoCellHeightUITableViewController {

    @IBOutlet weak var pgpPublicKeyURLTextField: UITextField!
    @IBOutlet weak var pgpPrivateKeyURLTextField: UITextField!

    let passwordStore = PasswordStore.shared
    let keychain = AppKeychain.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        pgpPublicKeyURLTextField.text = Defaults.pgpPublicKeyURL?.absoluteString
        pgpPrivateKeyURLTextField.text = Defaults.pgpPrivateKeyURL?.absoluteString
    }
    
    @IBAction func save(_ sender: Any) {
        let publicKeyUrl = pgpPublicKeyURLTextField.text
        if publicKeyUrl == nil || publicKeyUrl!.trimmed.isEmpty {
            return savePassphraseDialog()
        }
        if getScheme(from: pgpPrivateKeyURLTextField.text?.trimmed) == "http" {
            let savePassphraseAlert = UIAlertController(title: "HttpNotSecure".localize(), message: "ReallyUseHttp?".localize(), preferredStyle: .alert)
            savePassphraseAlert.addAction(UIAlertAction(title: "No".localize(), style: .default) { _ in })
            savePassphraseAlert.addAction(UIAlertAction(title: "Yes".localize(), style: .destructive) { _ in
                self.savePassphraseDialog()
            })
            return present(savePassphraseAlert, animated: true)
        }
        return savePassphraseDialog()
    }

    private func getScheme(from url: String?) -> String? {
        return url.flatMap(URL.init(string:))?.scheme
    }
}

extension PGPKeyUrlImportTableViewController: PGPKeyImporter {

    static let keySource = PGPKeySource.url
    static let label = "DownloadFromUrl".localize()

    func isReadyToUse() -> Bool {
        return validate(pgpKeyUrl: pgpPublicKeyURLTextField.text)
            && validate(pgpKeyUrl: pgpPrivateKeyURLTextField.text)
    }

    func importKeys() throws {
        Defaults.pgpPrivateKeyURL = URL(string: pgpPrivateKeyURLTextField.text!.trimmed)
        Defaults.pgpPublicKeyURL = URL(string: pgpPublicKeyURLTextField.text!.trimmed)

        try KeyFileManager.PublicPgp.importKey(from: Defaults.pgpPublicKeyURL!)
        try KeyFileManager.PrivatePgp.importKey(from: Defaults.pgpPrivateKeyURL!)
    }

    func doAfterImport() {
        Utils.alert(title: "RememberToRemoveKey".localize(), message: "RememberToRemoveKeyFromServer.".localize(), controller: self)
    }

    func saveImportedKeys() {
        performSegue(withIdentifier: "savePGPKeySegue", sender: self)
    }

    private func validate(pgpKeyUrl: String?) -> Bool {
        guard let scheme = getScheme(from: pgpKeyUrl) else {
            Utils.alert(title: "CannotSavePgpKey".localize(), message: "SetPgpKeyUrlsFirst.".localize(), controller: self)
            return false
        }
        guard scheme == "https" || scheme == "http" else {
            Utils.alert(title: "CannotSavePgpKey".localize(), message: "UseEitherHttpsOrHttp.".localize(), controller: self)
            return false
        }
        return true
    }
}
