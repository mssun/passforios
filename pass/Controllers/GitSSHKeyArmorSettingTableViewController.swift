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
        static let maxNumberOfGif = 100
        var numberOfSegments = 0
        var previousSegment = ""
        var key = ""
        var message = ""
        var hasStarted = false
        var isDone = false

        func reset() {
            numberOfSegments = 0
            previousSegment = ""
            key = ""
            message = "LookingForStartingFrame.".localize()
            hasStarted = false
            isDone = false
        }

        func addSegment(segment: String) {
            // skip duplicated segments
            guard segment != previousSegment else {
                return
            }
            previousSegment = segment

            // check whether we have found the first block
            if hasStarted == false {
                hasStarted = segment.contains("-----BEGIN")
            }
            guard hasStarted == true else {
                return
            }

            // check the number of segments
            numberOfSegments = numberOfSegments + 1
            guard numberOfSegments <= ScannedSSHKey.maxNumberOfGif else {
                key = "TooManyQrCodes".localize()
                return
            }

            // update full text and check whether we are done
            key.append(segment)
            if let index1 = key.range(of: "-----END")?.lowerBound,
                let _ = key.suffix(from: index1).range(of: "KEY-----")?.lowerBound {
                isDone = true
            }

            // update message
            message = "ScannedQrCodes(%d)".localize(numberOfSegments)
        }
    }
    var scanned = ScannedSSHKey()

    override func viewDidLoad() {
        super.viewDidLoad()
        armorPrivateKeyTextView.text = AppKeychain.get(for: SshKey.PRIVATE.getKeychainKey())
        armorPrivateKeyTextView.delegate = self

        scanPrivateKeyCell?.textLabel?.text = "ScanPrivateKeyQrCodes".localize()
        scanPrivateKeyCell?.textLabel?.textColor = Globals.blue
        scanPrivateKeyCell?.selectionStyle = .default
        scanPrivateKeyCell?.accessoryType = .disclosureIndicator
    }

    @IBAction func doneButtonTapped(_ sender: Any) {
        do {
            try passwordStore.initGitSSHKey(with: armorPrivateKeyTextView.text)
        } catch {
            Utils.alert(title: "CannotSave".localize(), message: "CannotSaveSshKey".localize(), controller: self, completion: nil)
        }
        SharedDefaults[.gitSSHKeySource] = "armor"
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
        scanned.addSegment(segment: line)
        if scanned.isDone {
            return (accept: true, message: "Done".localize())
        } else {
            return (accept: false, message: scanned.message)
        }
    }

    // MARK: - QRScannerControllerDelegate Methods
    func handleScannedOutput(line: String) {
        armorPrivateKeyTextView.text = scanned.key
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
