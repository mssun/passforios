//
//  GitSSHKeyArmorSettingTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 2/4/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import passKit

class GitSSHKeyArmorSettingTableViewController: AutoCellHeightUITableViewController, UITextViewDelegate, QRScannerControllerDelegate {
    @IBOutlet weak var armorPrivateKeyTextView: UITextView!
    @IBOutlet weak var scanPrivateKeyCell: UITableViewCell!

    var gitSSHPrivateKeyPassphrase: String?
    let passwordStore = PasswordStore.shared

    class ScannedSSHKey {
        var segments = [String]()
        var message = ""

        func reset() {
            self.segments.removeAll()
            message = "LookingForStartingFrame.".localize()
        }

        func addSegment(segment: String) -> (accept: Bool, message: String) {
            // Skip duplicated segments.
            guard segment != self.segments.last else {
                return (accept: false, message: self.message)
            }
            
            // Check whether we have found the first block.
            guard !self.segments.isEmpty || segment.contains("-----BEGIN") else {
                return (accept: false, message: self.message)
            }
            
            // Update the list of scanned segment and return.
            self.segments.append(segment)
            if segment.range(of: "-----END.*KEY-----", options: .regularExpression, range: nil, locale: nil) != nil {
                self.message = "Done".localize()
                return (accept: true, message: self.message)
            } else {
                self.message = "ScannedQrCodes(%d)".localize(self.segments.count)
                return (accept: false, message: self.message)
            }
        }
    }
    var scanned = ScannedSSHKey()

    override func viewDidLoad() {
        super.viewDidLoad()
        armorPrivateKeyTextView.delegate = self

        scanPrivateKeyCell?.textLabel?.text = "ScanPrivateKeyQrCodes".localize()
        scanPrivateKeyCell?.textLabel?.textColor = Colors.systemBlue
        scanPrivateKeyCell?.selectionStyle = .default
        scanPrivateKeyCell?.accessoryType = .disclosureIndicator
    }

    @IBAction func doneButtonTapped(_ sender: Any) {
        do {
            try passwordStore.initGitSSHKey(with: armorPrivateKeyTextView.text)
        } catch {
            Utils.alert(title: "CannotSave".localize(), message: "CannotSaveSshKey".localize(), controller: self, completion: nil)
        }
        Defaults.gitSSHKeySource = .armor
        Defaults.gitAuthenticationMethod = .key
        self.navigationController!.popViewController(animated: true)
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
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
            self.performSegue(withIdentifier: "showSSHScannerSegue", sender: self)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }


    // MARK: - QRScannerControllerDelegate Methods
    func checkScannedOutput(line: String) -> (accept: Bool, message: String) {
        return scanned.addSegment(segment: line)
    }

    // MARK: - QRScannerControllerDelegate Methods
    func handleScannedOutput(line: String) {
        armorPrivateKeyTextView.text = scanned.segments.joined(separator: "")
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showSSHScannerSegue" {
            if let navController = segue.destination as? UINavigationController {
                if let viewController = navController.topViewController as? QRScannerController {
                    viewController.delegate = self
                }
            } else if let viewController = segue.destination as? QRScannerController {
                viewController.delegate = self
            }
        }
    }

    @IBAction private func cancelSSHScanner(segue: UIStoryboardSegue) {

    }

}
