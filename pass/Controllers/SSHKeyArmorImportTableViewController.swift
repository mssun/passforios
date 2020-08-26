//
//  SSHKeyArmorImportTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 2/4/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import passKit
import UIKit

class SSHKeyArmorImportTableViewController: AutoCellHeightUITableViewController, UITextViewDelegate, QRScannerControllerDelegate {
    @IBOutlet var armorPrivateKeyTextView: UITextView!
    @IBOutlet var scanPrivateKeyCell: UITableViewCell!

    private var gitSSHPrivateKeyPassphrase: String?
    private var armorPrivateKey: String?

    private var scanner = QRKeyScanner(keyType: .sshPrivate)

    override func viewDidLoad() {
        super.viewDidLoad()
        armorPrivateKeyTextView.delegate = self

        scanPrivateKeyCell?.textLabel?.text = "ScanPrivateKeyQrCodes".localize()
        scanPrivateKeyCell?.selectionStyle = .default
        scanPrivateKeyCell?.accessoryType = .disclosureIndicator
    }

    @IBAction
    private func doneButtonTapped(_: Any) {
        armorPrivateKey = armorPrivateKeyTextView.text
        performSegue(withIdentifier: "importSSHKeySegue", sender: self)
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
        if selectedCell == scanPrivateKeyCell {
            scanner = QRKeyScanner(keyType: .sshPrivate)
            performSegue(withIdentifier: "showSSHScannerSegue", sender: self)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    // MARK: - QRScannerControllerDelegate Methods

    func checkScannedOutput(line: String) -> (accepted: Bool, message: String) {
        scanner.add(segment: line).unrolled
    }

    // MARK: - QRScannerControllerDelegate Methods

    func handleScannedOutput(line _: String) {
        armorPrivateKeyTextView.text = scanner.scannedKey
    }

    override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
        guard segue.identifier == "showSSHScannerSegue" else {
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

    @IBAction
    private func cancelSSHScanner(segue _: UIStoryboardSegue) {}
}

extension SSHKeyArmorImportTableViewController: KeyImporter {
    static let keySource = KeySource.armor
    static let label = "AsciiArmorEncryptedKey".localize()

    func isReadyToUse() -> Bool {
        guard !armorPrivateKeyTextView.text.isEmpty else {
            Utils.alert(title: "CannotSave".localize(), message: "SetPrivateKey.".localize(), controller: self)
            return false
        }
        return true
    }

    func importKeys() throws {
        try KeyFileManager.PrivateSsh.importKey(from: armorPrivateKey ?? "")
    }
}
