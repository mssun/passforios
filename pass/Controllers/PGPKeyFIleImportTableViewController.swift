//
//  PGPKeyFIleImportTableViewController.swift
//  pass
//
//  Created by Danny Moesch on 01.02.20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import passKit

class PGPKeyFileImportTableViewController: AutoCellHeightUITableViewController, AlertPresenting {
    @IBOutlet var pgpPublicKeyFile: UITableViewCell!
    @IBOutlet var pgpPrivateKeyFile: UITableViewCell!

    private var publicKey: String?
    private var privateKey: String?

    private enum KeyType { case none, `private`, `public` }
    private var currentlyPicking = KeyType.none

    @IBAction
    private func save(_: Any) {
        saveImportedKeys()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        let picker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .open)
        cell?.isSelected = false
        if cell == pgpPublicKeyFile {
            currentlyPicking = .public
        } else if cell == pgpPrivateKeyFile {
            currentlyPicking = .private
        } else {
            return
        }
        picker.delegate = self
        picker.shouldShowFileExtensions = true
        present(picker, animated: true, completion: nil)
    }
}

extension PGPKeyFileImportTableViewController: UIDocumentPickerDelegate {
    func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt url: [URL]) {
        guard let url = url.first else {
            return
        }
        let fileName = url.lastPathComponent
        do {
            // Start accessing a security-scoped resource.
            guard url.startAccessingSecurityScopedResource() else {
                // Handle the failure here.
                throw AppError.readingFile(fileName: fileName)
            }

            // Make sure you release the security-scoped resource when you are done.
            defer { url.stopAccessingSecurityScopedResource() }

            let fileContent = try String(contentsOf: url, encoding: .ascii)
            switch currentlyPicking {
            case .none:
                return
            case .public:
                publicKey = fileContent
                pgpPublicKeyFile.textLabel?.text = fileName
            case .private:
                privateKey = fileContent
                pgpPrivateKeyFile.textLabel?.text = fileName
            }
        } catch {
            let message = "FileCannotBeImported.".localize(fileName) | "UnderlyingError".localize(error.localizedDescription)
            presentFailureAlert(title: "CannotImportFile".localize(), message: message)
        }
    }
}

extension PGPKeyFileImportTableViewController: PGPKeyImporter {
    static let keySource = KeySource.file
    static let label = "LoadFromFiles".localize()

    func isReadyToUse() -> Bool {
        validate(key: publicKey) && (Defaults.isYubiKeyEnabled || validate(key: privateKey))
    }

    func importKeys() throws {
        if let publicKey = publicKey {
            try KeyFileManager.PublicPGP.importKey(from: publicKey)
        }
        if let privateKey = privateKey {
            try KeyFileManager.PrivatePGP.importKey(from: privateKey)
        }
    }

    func doAfterImport() {
        presentAlert(title: "RememberToRemoveKey".localize(), message: "RememberToRemoveKeyFromLocation.".localize())
    }

    func saveImportedKeys() {
        performSegue(withIdentifier: "savePGPKeySegue", sender: self)
    }

    private func validate(key: String?) -> Bool {
        guard key != nil else {
            presentFailureAlert(title: "CannotSavePgpKey".localize(), message: "KeyFileNotSet.".localize())
            return false
        }
        return true
    }
}
