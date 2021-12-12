//
//  PGPKeyURLImportTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 21/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import passKit
import UIKit

class PGPKeyURLImportTableViewController: AutoCellHeightUITableViewController {
    @IBOutlet var pgpPublicKeyURLTextField: UITextField!
    @IBOutlet var pgpPrivateKeyURLTextField: UITextField!

    var pgpPrivateKeyURL: URL?
    var pgpPublicKeyURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        pgpPublicKeyURLTextField.text = Defaults.pgpPublicKeyURL?.absoluteString
        pgpPrivateKeyURLTextField.text = Defaults.pgpPrivateKeyURL?.absoluteString
    }

    @IBAction
    private func save(_: Any) {
        guard let publicKeyURLText = pgpPublicKeyURLTextField.text,
              let publicKeyURL = URL(string: publicKeyURLText),
              let privateKeyURLText = pgpPrivateKeyURLTextField.text,
              let privateKeyURL = URL(string: privateKeyURLText) else {
            Utils.alert(title: "CannotSavePgpKey".localize(), message: "SetPgpKeyUrlsFirst.".localize(), controller: self)
            return
        }
        if privateKeyURL.scheme?.lowercased() == "http" || publicKeyURL.scheme?.lowercased() == "http" {
            Utils.alert(title: "HttpNotSecure".localize(), message: "ReallyUseHttp.".localize(), controller: self)
        }
        pgpPrivateKeyURL = privateKeyURL
        pgpPublicKeyURL = publicKeyURL
        saveImportedKeys()
    }
}

extension PGPKeyURLImportTableViewController: PGPKeyImporter {
    static let keySource = KeySource.url
    static let label = "DownloadFromUrl".localize()

    func isReadyToUse() -> Bool {
        validate(pgpKeyURL: pgpPublicKeyURLTextField.text ?? "")
            && validate(pgpKeyURL: pgpPrivateKeyURLTextField.text ?? "")
    }

    func importKeys() throws {
        Defaults.pgpPrivateKeyURL = pgpPrivateKeyURL
        Defaults.pgpPublicKeyURL = pgpPublicKeyURL

        try KeyFileManager.PublicPGP.importKey(from: Defaults.pgpPublicKeyURL!)
        try KeyFileManager.PrivatePGP.importKey(from: Defaults.pgpPrivateKeyURL!)
    }

    func doAfterImport() {
        Utils.alert(title: "RememberToRemoveKey".localize(), message: "RememberToRemoveKeyFromServer.".localize(), controller: self)
    }

    func saveImportedKeys() {
        performSegue(withIdentifier: "savePGPKeySegue", sender: self)
    }

    private func validate(pgpKeyURL: String) -> Bool {
        guard let url = URL(string: pgpKeyURL) else {
            Utils.alert(title: "CannotSavePgpKey".localize(), message: "SetPgpKeyUrlsFirst.".localize(), controller: self)
            return false
        }
        guard url.scheme == "https" || url.scheme == "http" else {
            Utils.alert(title: "CannotSavePgpKey".localize(), message: "UseEitherHttpsOrHttp.".localize(), controller: self)
            return false
        }
        return true
    }
}
