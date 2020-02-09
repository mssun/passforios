//
//  PGPKeyUrlTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 21/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import passKit

class PGPKeyUrlTableViewController: AutoCellHeightUITableViewController {

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
        savePassphraseDialog()
    }
}

extension PGPKeyUrlTableViewController: PGPKeyImporter {

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
        Utils.alert(title: "RememberToRemoveKey".localize(), message: "RememberToRemoveKeyFromServer.".localize(), controller: self, completion: nil)
    }

    func saveImportedKeys() {
        self.performSegue(withIdentifier: "savePGPKeySegue", sender: self)
    }

    private func validate(pgpKeyUrl: String?) -> Bool {
        guard let pgpKeyUrl = pgpKeyUrl, let url = URL(string: pgpKeyUrl), let scheme = url.scheme else {
            Utils.alert(title: "CannotSavePgpKey".localize(), message: "SetPgpKeyUrlFirst.".localize(), controller: self, completion: nil)
            return false
        }
        guard scheme == "https" else {
            Utils.alert(title: "CannotSavePgpKey".localize(), message: "UseHttps.".localize(), controller: self, completion: nil)
            return false
        }
        return true
    }
}
