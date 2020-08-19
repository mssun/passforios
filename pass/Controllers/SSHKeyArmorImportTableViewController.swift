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

    var gitSSHPrivateKeyPassphrase: String?
    var armorPrivateKey: String?

    class ScannedSSHKey {
        var segments = [String]()
        var message = ""

        func reset() {
            segments.removeAll()
            message = "LookingForStartingFrame.".localize()
        }

        func addSegment(segment: String) -> (accept: Bool, message: String) {
            // Skip duplicated segments.
            guard segment != segments.last else {
                return (accept: false, message: message)
            }

            // Check whether we have found the first block.
            guard !segments.isEmpty || segment.contains("-----BEGIN") else {
                return (accept: false, message: message)
            }

            // Update the list of scanned segment and return.
            segments.append(segment)
            if segment.range(of: "-----END.*KEY-----", options: .regularExpression, range: nil, locale: nil) != nil {
                message = "Done".localize()
                return (accept: true, message: message)
            } else {
                message = "ScannedQrCodes(%d)".localize(segments.count)
                return (accept: false, message: message)
            }
        }
    }

    var scanned = ScannedSSHKey()

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
            scanned.reset()
            performSegue(withIdentifier: "showSSHScannerSegue", sender: self)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    // MARK: - QRScannerControllerDelegate Methods

    func checkScannedOutput(line: String) -> (accept: Bool, message: String) {
        return scanned.addSegment(segment: line)
    }

    // MARK: - QRScannerControllerDelegate Methods

    func handleScannedOutput(line _: String) {
        armorPrivateKeyTextView.text = scanned.segments.joined()
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
