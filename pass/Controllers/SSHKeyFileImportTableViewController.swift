//
//  SSHKeyFileImportTableViewController.swift
//  pass
//
//  Created by Danny Moesch on 15.02.20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import passKit
import SVProgressHUD

class SSHKeyFileImportTableViewController: AutoCellHeightUITableViewController {

    @IBOutlet weak var sshPrivateKeyFile: UITableViewCell!

    private var privateKey: String? = nil

    @IBAction func doneButtonTapped(_ sender: Any) {
        performSegue(withIdentifier: "importSSHKeySegue", sender: self)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        let picker = UIDocumentPickerViewController(documentTypes: ["public.data"], in: .open)
        cell?.isSelected = false
        guard cell == sshPrivateKeyFile else {
            return
        }
        picker.delegate = self
        if #available(iOS 13.0, *) {
            picker.shouldShowFileExtensions = true
        }
        present(picker, animated: true, completion: nil)
    }
}

extension SSHKeyFileImportTableViewController: UIDocumentPickerDelegate {

    func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt url: [URL]) {
        guard let url = url.first else {
            return
        }
        let fileName = url.lastPathComponent
        do {
            privateKey = try String(contentsOf: url, encoding: .ascii)
            sshPrivateKeyFile.textLabel?.text = fileName
        } catch {
            Utils.alert(title: "CannotImportFile".localize(), message: "FileCannotBeImported.".localize(fileName), controller: self)
        }
    }
}

extension SSHKeyFileImportTableViewController: KeyImporter {

    static let keySource = KeySource.file
    static let label = "LoadFromFiles".localize()

    func isReadyToUse() -> Bool {
        guard privateKey != nil else {
            Utils.alert(title: "CannotSave".localize(), message: "SetPrivateKeyUrl.".localize(), controller: self)
            return false
        }
        return true
    }

    func importKeys() throws {
        guard let privateKey = privateKey else {
            return
        }
        try KeyFileManager.PrivateSsh.importKey(from: privateKey)
    }
}
