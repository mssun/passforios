//
//  PGPKeyArmorImportTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 17/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import passKit
import UIKit

class PGPKeyArmorImportTableViewController: AutoCellHeightUITableViewController, UITextViewDelegate, QRScannerControllerDelegate {
    @IBOutlet var armorPublicKeyTextView: UITextView!
    @IBOutlet var armorPrivateKeyTextView: UITextView!
    @IBOutlet var scanPublicKeyCell: UITableViewCell!
    @IBOutlet var scanPrivateKeyCell: UITableViewCell!

    private var armorPublicKey: String?
    private var armorPrivateKey: String?

    private var scanner = QRKeyScanner(keyType: .pgpPublic)

    override func viewDidLoad() {
        super.viewDidLoad()

        scanPublicKeyCell?.textLabel?.text = "ScanPublicKeyQrCodes".localize()
        scanPublicKeyCell?.selectionStyle = .default
        scanPublicKeyCell?.accessoryType = .disclosureIndicator

        scanPrivateKeyCell?.textLabel?.text = "ScanPrivateKeyQrCodes".localize()
        scanPrivateKeyCell?.selectionStyle = .default
        scanPrivateKeyCell?.accessoryType = .disclosureIndicator
    }

    @IBAction
    private func save(_: Any) {
        armorPublicKey = armorPublicKeyTextView.text
        armorPrivateKey = armorPrivateKeyTextView.text
        saveImportedKeys()
    }

    func textView(_: UITextView, shouldChangeTextIn _: NSRange, replacementText text: String) -> Bool {
        if text == UIPasteboard.general.string {
            // user pastes something, do the copy here again and clear the pasteboard in 45s
            SecurePasteboard.shared.copy(textToCopy: text)
        }
        return true
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedCell = tableView.cellForRow(at: indexPath)
        if selectedCell == scanPublicKeyCell {
            scanner = QRKeyScanner(keyType: .pgpPublic)
        } else if selectedCell == scanPrivateKeyCell {
            scanner = QRKeyScanner(keyType: .pgpPrivate)
        }
        performSegue(withIdentifier: "showPGPScannerSegue", sender: self)
        tableView.deselectRow(at: indexPath, animated: true)
    }

    // MARK: - QRScannerControllerDelegate Methods

    func checkScannedOutput(line: String) -> (accepted: Bool, message: String) {
        scanner.add(segment: line).unrolled
    }

    // MARK: - QRScannerControllerDelegate Methods

    func handleScannedOutput(line _: String) {
        let key = scanner.scannedKey
        switch scanner.keyType {
        case .pgpPublic:
            armorPublicKeyTextView.text += key
        case .pgpPrivate:
            armorPrivateKeyTextView.text += key
        default:
            return
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
        guard segue.identifier == "showPGPScannerSegue" else {
            return
        }
        if let navController = segue.destination as? UINavigationController {
            if let viewController = navController.topViewController as? QRScannerController {
                viewController.delegate = self
            }
        } else if let viewController = segue.destination as? QRScannerController {
            viewController.delegate = self
        }
    }
}

extension PGPKeyArmorImportTableViewController: PGPKeyImporter {
    static let keySource = KeySource.armor
    static let label = "AsciiArmorEncryptedKey".localize()

    func isReadyToUse() -> Bool {
        guard !armorPublicKeyTextView.text.isEmpty else {
            Utils.alert(title: "CannotSave".localize(), message: "SetPublicKey.".localize(), controller: self, completion: nil)
            return false
        }
        guard Defaults.isYubiKeyEnabled || !armorPrivateKeyTextView.text.isEmpty else {
            Utils.alert(title: "CannotSave".localize(), message: "SetPrivateKey.".localize(), controller: self, completion: nil)
            return false
        }
        return true
    }

    func importKeys() throws {
        try KeyFileManager.PublicPGP.importKey(from: armorPublicKey ?? "")
        try KeyFileManager.PrivatePGP.importKey(from: armorPrivateKey ?? "")
    }

    func saveImportedKeys() {
        performSegue(withIdentifier: "savePGPKeySegue", sender: self)
    }
}
