//
//  GitSSHKeyArmorSettingTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 2/4/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import SwiftyUserDefaults

class GitSSHKeyArmorSettingTableViewController: UITableViewController, UITextViewDelegate, QRScannerControllerDelegate {
    @IBOutlet weak var armorPrivateKeyTextView: UITextView!
    @IBOutlet weak var scanPrivateKeyCell: UITableViewCell!
    
    var gitSSHPrivateKeyPassphrase: String?
    let passwordStore = PasswordStore.shared
    
    private var recentPastedText = ""
    
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
            message = "Looking for the starting frame."
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
                key = "Too many QR codes"
                return
            }
            
            // update full text and check whether we are done
            key.append(segment)
            if let index1 = key.range(of: "-----END")?.lowerBound,
                let _ = key.substring(from: index1).range(of: "KEY-----")?.lowerBound {
                isDone = true
            }
            
            // update message
            message = "\(numberOfSegments) scanned QR codes."
        }
    }
    var scanned = ScannedSSHKey()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        armorPrivateKeyTextView.text = Defaults[.gitSSHPrivateKeyArmor]
        armorPrivateKeyTextView.delegate = self
        
        scanPrivateKeyCell?.textLabel?.text = "Scan Private Key QR Codes"
        scanPrivateKeyCell?.textLabel?.textColor = Globals.blue
        scanPrivateKeyCell?.selectionStyle = .default
        scanPrivateKeyCell?.accessoryType = .disclosureIndicator
    }
    
    @IBAction func doneButtonTapped(_ sender: Any) {
        Defaults[.gitSSHPrivateKeyArmor] = armorPrivateKeyTextView.text
        do {
            try passwordStore.initGitSSHKey(with: armorPrivateKeyTextView.text, .secret)
        } catch {
            Utils.alert(title: "Cannot Save", message: "Cannot Save SSH Key", controller: self, completion: nil)
        }
        Defaults[.gitSSHKeySource] = "armor"
        self.navigationController!.popViewController(animated: true)
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == UIPasteboard.general.string {
            // user pastes something, get ready to clear in 10s
            recentPastedText = text
            DispatchQueue.global(qos: .background).asyncAfter(deadline: DispatchTime.now() + 10) { [weak weakSelf = self] in
                if let pasteboardString = UIPasteboard.general.string,
                    pasteboardString == weakSelf?.recentPastedText {
                    UIPasteboard.general.string = ""
                }
            }
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
            return (accept: true, message: "Done")
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
