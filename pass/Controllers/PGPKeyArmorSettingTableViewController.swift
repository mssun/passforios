//
//  PGPKeyArmorSettingTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 17/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import passKit

class PGPKeyArmorSettingTableViewController: AutoCellHeightUITableViewController, UITextViewDelegate, QRScannerControllerDelegate {
    @IBOutlet weak var armorPublicKeyTextView: UITextView!
    @IBOutlet weak var armorPrivateKeyTextView: UITextView!
    @IBOutlet weak var scanPublicKeyCell: UITableViewCell!
    @IBOutlet weak var scanPrivateKeyCell: UITableViewCell!

    var pgpPassphrase: String?
    let passwordStore = PasswordStore.shared

    class ScannedPGPKey {
        static let maxNumberOfGif = 100
        enum KeyType {
            case publicKey, privateKey
        }
        var keyType = KeyType.publicKey
        var numberOfSegments = 0
        var previousSegment = ""
        var key = ""
        var message = ""
        var hasStarted = false
        var isDone = false

        func reset(keytype: KeyType) {
            self.keyType = keytype
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
                let findPublic = segment.contains("-----BEGIN PGP PUBLIC KEY BLOCK-----")
                let findPrivate = segment.contains("-----BEGIN PGP PRIVATE KEY BLOCK-----")
                switch keyType {
                case .publicKey:
                    if findPrivate {
                        message = "ScanPrivateKey.".localize()
                    }
                    hasStarted = findPublic
                case .privateKey:
                    if findPublic {
                        message = "ScanPrivateKey.".localize()
                    }
                    hasStarted = findPrivate
                }
            }
            guard hasStarted == true else {
                return
            }

            // check the number of segments
            numberOfSegments = numberOfSegments + 1
            guard numberOfSegments <= ScannedPGPKey.maxNumberOfGif else {
                key = "TooManyQrCodes".localize()
                return
            }

            // update full text and check whether we are done
            key.append(segment)
            if key.contains("-----END PGP PUBLIC KEY BLOCK-----") || key.contains("-----END PGP PRIVATE KEY BLOCK-----") {
                isDone = true
            }

            // update message
            message = "ScannedQrCodes(%d)".localize(numberOfSegments)
        }
    }
    var scanned = ScannedPGPKey()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        pgpPassphrase = passwordStore.pgpKeyPassphrase

        scanPublicKeyCell?.textLabel?.text = "ScanPublicKeyQrCodes".localize()
        scanPublicKeyCell?.textLabel?.textColor = Globals.blue
        scanPublicKeyCell?.selectionStyle = .default
        scanPublicKeyCell?.accessoryType = .disclosureIndicator

        scanPrivateKeyCell?.textLabel?.text = "ScanPrivateKeyQrCodes".localize()
        scanPrivateKeyCell?.textLabel?.textColor = Globals.blue
        scanPrivateKeyCell?.selectionStyle = .default
        scanPrivateKeyCell?.accessoryType = .disclosureIndicator
    }

    @IBAction func save(_ sender: Any) {
        guard armorPublicKeyTextView.text.isEmpty == false else {
            Utils.alert(title: "CannotSave".localize(), message: "SetPublicKey.".localize(), controller: self, completion: nil)
            return
        }
        guard armorPrivateKeyTextView.text.isEmpty == false else {
            Utils.alert(title: "CannotSave".localize(), message: "SetPrivateKey.".localize(), controller: self, completion: nil)
            return
        }
        let savePassphraseAlert = UIAlertController(title: "Passphrase".localize(), message: "WantToSavePassphrase?".localize(), preferredStyle: UIAlertController.Style.alert)
        // no
        savePassphraseAlert.addAction(UIAlertAction(title: "No".localize(), style: UIAlertAction.Style.default) { _ in
            self.pgpPassphrase = nil
            SharedDefaults[.isRememberPGPPassphraseOn] = false
            self.performSegue(withIdentifier: "savePGPKeySegue", sender: self)
        })
        // yes
        savePassphraseAlert.addAction(UIAlertAction(title: "Yes".localize(), style: UIAlertAction.Style.destructive) {_ in
            // ask for the passphrase
            let alert = UIAlertController(title: "Passphrase".localize(), message: "FillInPgpPassphrase.".localize(), preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "Ok".localize(), style: UIAlertAction.Style.default, handler: {_ in
                self.pgpPassphrase = alert.textFields?.first?.text
                SharedDefaults[.isRememberPGPPassphraseOn] = true
                self.performSegue(withIdentifier: "savePGPKeySegue", sender: self)
            }))
            alert.addTextField(configurationHandler: {(textField: UITextField!) in
                textField.text = self.pgpPassphrase
                textField.isSecureTextEntry = true
            })
            self.present(alert, animated: true, completion: nil)
        })
        self.present(savePassphraseAlert, animated: true, completion: nil)
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
        if selectedCell == scanPublicKeyCell {
            scanned.reset(keytype: ScannedPGPKey.KeyType.publicKey)
            self.performSegue(withIdentifier: "showPGPScannerSegue", sender: self)
        } else if selectedCell == scanPrivateKeyCell {
            scanned.reset(keytype: ScannedPGPKey.KeyType.privateKey)
            self.performSegue(withIdentifier: "showPGPScannerSegue", sender: self)
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
        switch scanned.keyType {
        case .publicKey:
            armorPublicKeyTextView.text = scanned.key
        case .privateKey:
            armorPrivateKeyTextView.text = scanned.key
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showPGPScannerSegue" {
            if let navController = segue.destination as? UINavigationController {
                if let viewController = navController.topViewController as? QRScannerController {
                    viewController.delegate = self
                }
            } else if let viewController = segue.destination as? QRScannerController {
                viewController.delegate = self
            }
        }
    }
}
