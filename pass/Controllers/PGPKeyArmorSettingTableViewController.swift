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

    let passwordStore = PasswordStore.shared
    let keychain = AppKeychain.shared
    
    class ScannedPGPKey {
        enum KeyType {
            case publicKey, privateKey
        }
        var keyType = KeyType.publicKey
        var segments = [String]()
        var message = ""

        func reset(keytype: KeyType) {
            self.keyType = keytype
            self.segments.removeAll()
            message = "LookingForStartingFrame.".localize()
        }

        func addSegment(segment: String) -> (accept: Bool, message: String) {
            let keyTypeStr = self.keyType == .publicKey ? "Public" : "Private"
            let theOtherKeyTypeStr = self.keyType == .publicKey ? "Private" : "Public"
            
            // Skip duplicated segments.
            guard segment != self.segments.last else {
                return (accept: false, message: self.message)
            }

            // Check whether we have found the first block.
            guard !self.segments.isEmpty || segment.contains("-----BEGIN PGP \(keyTypeStr.uppercased()) KEY BLOCK-----") else {
                // Check whether we are scanning the wrong key type.
                if segment.contains("-----BEGIN PGP \(theOtherKeyTypeStr.uppercased()) KEY BLOCK-----") {
                    self.message = "Scan\(keyTypeStr)Key.".localize()
                }
                return (accept: false, message: self.message)
            }
            
            // Update the list of scanned segment and return.
            self.segments.append(segment)
            if segment.contains("-----END PGP .* KEY BLOCK-----") {
                self.message = "Done".localize()
                return (accept: true, message: self.message)
            } else {
                self.message = "ScannedQrCodes(%d)".localize(self.segments.count)
                print(self.message)
                return (accept: false, message: self.message)
            }
        }
    }
    var scanned = ScannedPGPKey()

    override func viewDidLoad() {
        super.viewDidLoad()

        scanPublicKeyCell?.textLabel?.text = "ScanPublicKeyQrCodes".localize()
        scanPublicKeyCell?.textLabel?.textColor = Colors.systemBlue
        scanPublicKeyCell?.selectionStyle = .default
        scanPublicKeyCell?.accessoryType = .disclosureIndicator

        scanPrivateKeyCell?.textLabel?.text = "ScanPrivateKeyQrCodes".localize()
        scanPrivateKeyCell?.textLabel?.textColor = Colors.systemBlue
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
            self.keychain.removeContent(for: Globals.pgpKeyPassphrase)
            SharedDefaults[.isRememberPGPPassphraseOn] = false
            self.performSegue(withIdentifier: "savePGPKeySegue", sender: self)
        })
        // yes
        savePassphraseAlert.addAction(UIAlertAction(title: "Yes".localize(), style: UIAlertAction.Style.destructive) {_ in
            // ask for the passphrase
            let alert = UIAlertController(title: "Passphrase".localize(), message: "FillInPgpPassphrase.".localize(), preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "Ok".localize(), style: UIAlertAction.Style.default, handler: {_ in
                self.keychain.add(string: alert.textFields?.first?.text, for: Globals.pgpKeyPassphrase)
                SharedDefaults[.isRememberPGPPassphraseOn] = true
                self.performSegue(withIdentifier: "savePGPKeySegue", sender: self)
            }))
            alert.addTextField(configurationHandler: {(textField: UITextField!) in
                textField.text = self.keychain.get(for: Globals.pgpKeyPassphrase)
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
        return scanned.addSegment(segment: line)
    }

    // MARK: - QRScannerControllerDelegate Methods
    func handleScannedOutput(line: String) {
        let key = scanned.segments.joined(separator: "")
        switch scanned.keyType {
        case .publicKey:
            armorPublicKeyTextView.text = key
        case .privateKey:
            armorPrivateKeyTextView.text = key
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
