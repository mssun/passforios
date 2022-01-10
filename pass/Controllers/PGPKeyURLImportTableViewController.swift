//
//  PGPKeyURLImportTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 21/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import passKit
import UIKit

class PGPKeyURLImportTableViewController: AutoCellHeightUITableViewController, AlertPresenting {
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
        pgpPublicKeyURL = validate(pgpKeyURLText: pgpPublicKeyURLTextField.text)

        if !Defaults.isYubiKeyEnabled {
            pgpPrivateKeyURL = validate(pgpKeyURLText: pgpPrivateKeyURLTextField.text)
        }
        saveImportedKeys()
    }
}

extension PGPKeyURLImportTableViewController: PGPKeyImporter {
    static let keySource = KeySource.url
    static let label = "DownloadFromUrl".localize()

    func isReadyToUse() -> Bool {
        validate(pgpKeyURLText: pgpPublicKeyURLTextField.text) != nil
            && (Defaults.isYubiKeyEnabled || validate(pgpKeyURLText: pgpPrivateKeyURLTextField.text ?? "") != nil)
    }

    func importKeys() throws {
        if let pgpPrivateKeyURL = pgpPrivateKeyURL {
            Defaults.pgpPrivateKeyURL = pgpPrivateKeyURL
            try KeyFileManager.PrivatePGP.importKey(from: pgpPrivateKeyURL)
        }

        if let pgpPublicKeyURL = pgpPublicKeyURL {
            Defaults.pgpPublicKeyURL = pgpPublicKeyURL
            try KeyFileManager.PublicPGP.importKey(from: pgpPublicKeyURL)
        }
    }

    func doAfterImport() {
        presentAlert(title: "RememberToRemoveKey".localize(), message: "RememberToRemoveKeyFromServer.".localize())
    }

    func saveImportedKeys() {
        performSegue(withIdentifier: "savePGPKeySegue", sender: self)
    }

    private func validate(pgpKeyURLText: String?) -> URL? {
        guard let pgpKeyURL = pgpKeyURLText, let url = URL(string: pgpKeyURL) else {
            presentFailureAlert(title: "CannotSavePgpKey".localize(), message: "SetPgpKeyUrlsFirst.".localize())
            return nil
        }
        guard url.scheme == "https" || url.scheme == "http" else {
            presentFailureAlert(title: "CannotSavePgpKey".localize(), message: "UseEitherHttpsOrHttp.".localize())
            return nil
        }
        return url
    }
}
