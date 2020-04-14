//
//  PGPKeyFileImportTableViewController.swift
//  pass
//
//  Created by Danny Moesch on 01.02.20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import passKit

class PGPKeyFileImportTableViewController: AutoCellHeightUITableViewController {

    @IBOutlet weak var pgpPublicKeyFile: UITableViewCell!
    @IBOutlet weak var pgpPrivateKeyFile: UITableViewCell!

    private var publicKey: String? = nil
    private var privateKey: String? = nil

    private enum KeyType { case none, `private`, `public` }
    private var currentlyPicking = KeyType.none

    @IBAction func save(_ sender: Any) {
        self.saveImportedKeys()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        let picker = UIDocumentPickerViewController(documentTypes: ["public.data"], in: .open)
        cell?.isSelected = false
        if cell == pgpPublicKeyFile {
            currentlyPicking = .public
        } else if cell == pgpPrivateKeyFile {
            currentlyPicking = .private
        } else {
            return
        }
        picker.delegate = self
        if #available(iOS 13.0, *) {
            picker.shouldShowFileExtensions = true
        }
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
                throw AppError.ReadingFile(fileName)
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
            Utils.alert(title: "CannotImportFile".localize(), message: message, controller: self)
        }
    }
}

extension PGPKeyFileImportTableViewController: PGPKeyImporter {

    static let keySource = KeySource.file
    static let label = "LoadFromFiles".localize()

    func isReadyToUse() -> Bool {
        return validate(key: publicKey) && validate(key: privateKey)
    }

    func importKeys() throws {
        guard let publicKey = publicKey, let privateKey = privateKey else {
            return
        }
        try KeyFileManager.PublicPgp.importKey(from: publicKey)
        try KeyFileManager.PrivatePgp.importKey(from: privateKey)
    }

    func doAfterImport() {
        Utils.alert(title: "RememberToRemoveKey".localize(), message: "RememberToRemoveKeyFromLocation.".localize(), controller: self)
    }

    func saveImportedKeys() {
        performSegue(withIdentifier: "savePGPKeySegue", sender: self)
    }

    private func validate(key: String?) -> Bool {
        guard key != nil else {
            Utils.alert(title: "CannotSavePgpKey".localize(), message: "KeyFileNotSet.".localize(), controller: self)
            return false
        }
        return true
    }
}
