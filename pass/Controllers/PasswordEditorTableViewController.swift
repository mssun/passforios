//
//  PasswordEditorTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 12/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import OneTimePassword
import passKit

enum PasswordEditorCellType {
    case nameCell, fillPasswordCell, passwordLengthCell, additionsCell, deletePasswordCell, scanQRCodeCell
}

enum PasswordEditorCellKey {
    case type, title, content, placeholders
}

class PasswordEditorTableViewController: UITableViewController, FillPasswordTableViewCellDelegate, PasswordSettingSliderTableViewCellDelegate, QRScannerControllerDelegate, UITextFieldDelegate, UITextViewDelegate {
    
    var tableData = [
        [Dictionary<PasswordEditorCellKey, Any>]
        ]()
    var password: Password?
    
    private var navigationItemTitle: String?
    
    private var sectionHeaderTitles = ["name", "password", "additions",""].map {$0.uppercased()}
    private var sectionFooterTitles = ["", "", "Use YAML format for additional fields.", ""]
    private let nameSection = 0
    private let passwordSection = 1
    private let additionsSection = 2
    private var hidePasswordSettings = true
    
    var nameCell: TextFieldTableViewCell?
    var fillPasswordCell: FillPasswordTableViewCell?
    private var passwordLengthCell: SliderTableViewCell?
    var additionsCell: TextViewTableViewCell?
    private var deletePasswordCell: UITableViewCell?
    private var scanQRCodeCell: UITableViewCell?
    
    override func loadView() {
        super.loadView()
        
        deletePasswordCell = UITableViewCell(style: .default, reuseIdentifier: "default")
        deletePasswordCell!.textLabel?.text = "Delete Password"
        deletePasswordCell!.textLabel?.textColor = Globals.red
        deletePasswordCell?.selectionStyle = .default
        
        scanQRCodeCell = UITableViewCell(style: .default, reuseIdentifier: "default")
        scanQRCodeCell?.textLabel?.text = "Add One-Time Password"
        scanQRCodeCell?.textLabel?.textColor = Globals.blue
        scanQRCodeCell?.selectionStyle = .default
        scanQRCodeCell?.accessoryType = .disclosureIndicator
//        scanQRCodeCell?.imageView?.image = #imageLiteral(resourceName: "Camera").withRenderingMode(.alwaysTemplate)
//        scanQRCodeCell?.imageView?.tintColor = Globals.blue
//        scanQRCodeCell?.imageView?.contentMode = .scaleAspectFit
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if navigationItemTitle != nil {
            navigationItem.title = navigationItemTitle
        }
        
        tableView.register(UINib(nibName: "TextFieldTableViewCell", bundle: nil), forCellReuseIdentifier: "textFieldCell")
        tableView.register(UINib(nibName: "TextViewTableViewCell", bundle: nil), forCellReuseIdentifier: "textViewCell")
        tableView.register(UINib(nibName: "FillPasswordTableViewCell", bundle: nil), forCellReuseIdentifier: "fillPasswordCell")
        tableView.register(UINib(nibName: "SliderTableViewCell", bundle: nil), forCellReuseIdentifier: "passwordLengthCell")
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 48
        self.tableView.sectionFooterHeight = UITableViewAutomaticDimension;
        self.tableView.estimatedSectionFooterHeight = 0;
    }
    override func viewDidLayoutSubviews() {
       additionsCell?.contentTextView.setContentOffset(.zero, animated: false)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellData = tableData[indexPath.section][indexPath.row]
        
        switch cellData[PasswordEditorCellKey.type] as! PasswordEditorCellType {
        case .nameCell:
            nameCell = tableView.dequeueReusableCell(withIdentifier: "textFieldCell", for: indexPath) as? TextFieldTableViewCell
            nameCell?.contentTextField.delegate = self
            nameCell?.setContent(content: cellData[PasswordEditorCellKey.content] as? String)
            return nameCell!
        case .fillPasswordCell:
            fillPasswordCell = tableView.dequeueReusableCell(withIdentifier: "fillPasswordCell", for: indexPath) as? FillPasswordTableViewCell
            fillPasswordCell?.delegate = self
            fillPasswordCell?.contentTextField.delegate = self
            fillPasswordCell?.setContent(content: cellData[PasswordEditorCellKey.content] as? String)
            if tableData[passwordSection].count == 1 {
                fillPasswordCell?.settingButton.isHidden = true
            }
            return fillPasswordCell!
        case .passwordLengthCell:
            passwordLengthCell = tableView.dequeueReusableCell(withIdentifier: "passwordLengthCell", for: indexPath) as? SliderTableViewCell
            let lengthSetting = Globals.passwordDefaultLength[SharedDefaults[.passwordGeneratorFlavor]] ??
                Globals.passwordDefaultLength["Random"]
            let minimumLength = lengthSetting?.min ?? 0
            let maximumLength = lengthSetting?.max ?? 0
            var defaultLength = lengthSetting?.def ?? 0
            if let currentPasswordLength = (tableData[passwordSection][0][PasswordEditorCellKey.content] as? String)?.count,
                currentPasswordLength >= minimumLength,
                currentPasswordLength <= maximumLength {
                defaultLength = currentPasswordLength
            }
            passwordLengthCell?.reset(title: "Length",
                                      minimumValue: minimumLength,
                                      maximumValue: maximumLength,
                                      defaultValue: defaultLength)
            passwordLengthCell?.delegate = self
            return passwordLengthCell!
        case .additionsCell:
            additionsCell = tableView.dequeueReusableCell(withIdentifier: "textViewCell", for: indexPath) as?TextViewTableViewCell
            additionsCell?.contentTextView.delegate = self
            additionsCell?.setContent(content: cellData[PasswordEditorCellKey.content] as? String)
            return additionsCell!
        case .deletePasswordCell:
            return deletePasswordCell!
        case .scanQRCodeCell:
            return scanQRCodeCell!
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 44
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return tableData.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == passwordSection, hidePasswordSettings {
            // hide the password section, only the password should be shown
            return 1
        } else {
            return tableData[section].count
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionHeaderTitles[section]
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sectionFooterTitles[section]
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedCell = tableView.cellForRow(at: indexPath)
        if selectedCell == deletePasswordCell {
            let alert = UIAlertController(title: "Delete Password?", message: nil, preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "Delete", style: UIAlertActionStyle.destructive, handler: {[unowned self] (action) -> Void in
                self.performSegue(withIdentifier: "deletePasswordSegue", sender: self)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler:nil))
            self.present(alert, animated: true, completion: nil)
        } else if selectedCell == scanQRCodeCell {
            self.performSegue(withIdentifier: "showQRScannerSegue", sender: self)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // generate password, copy to pasteboard, and set the cell
    // check whether the current password looks like an OTP field
    func generateAndCopyPassword() {
        if let currentPassword = fillPasswordCell?.getContent(),
            Password.LooksLikeOTP(line: currentPassword) {
            let alert = UIAlertController(title: "Overwrite?", message: "Overwrite the one-time password configuration?", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "Yes", style: UIAlertActionStyle.destructive, handler: {_ in
                self.generateAndCopyPasswordNoOtpCheck()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        } else {
            self.generateAndCopyPasswordNoOtpCheck()
        }
    }
    
    // generate the password, don't care whether the original line is otp
    func generateAndCopyPasswordNoOtpCheck() {
        // show password settings (e.g., the length slider)
        if hidePasswordSettings == true {
            hidePasswordSettings = false
            tableView.reloadSections([passwordSection], with: .fade)
        }
        let length = passwordLengthCell?.roundedValue ?? 0
        let plainPassword = Utils.generatePassword(length: length)
        SecurePasteboard.shared.copy(textToCopy: plainPassword)
        
        // update tableData so to make sure reloadData() works correctly
        tableData[passwordSection][0][PasswordEditorCellKey.content] = plainPassword
        
        // update cell manually, no need to call reloadData()
        fillPasswordCell?.setContent(content: plainPassword)
    }
    
    func showHidePasswordSettings() {
        hidePasswordSettings = !hidePasswordSettings
        tableView.reloadSections([passwordSection], with: .fade)
    }
    
    func insertScannedOTPFields(_ otpauth: String) {
        // update tableData
        var additionsString = ""
        if let additionsPlainText = (tableData[additionsSection][0][PasswordEditorCellKey.content] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), additionsPlainText != "" {
            additionsString = additionsPlainText + "\n" + otpauth
        } else {
            additionsString = otpauth
        }
        tableData[additionsSection][0][PasswordEditorCellKey.content] = additionsString
        
        // reload the additions cell
        additionsCell?.setContent(content: additionsString)
    }
    
    // MARK: - QRScannerControllerDelegate Methods
    func checkScannedOutput(line: String) -> (accept: Bool, message: String) {
        if let url = URL(string: line), let _ = Token(url: url) {
            return (accept: true, message: "Valid token URL")
        } else {
            return (accept: false, message: "Invalid token URL")
        }
    }
    
    // MARK: - QRScannerControllerDelegate Methods
    func handleScannedOutput(line: String) {
        insertScannedOTPFields(line)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showQRScannerSegue" {
            if let navController = segue.destination as? UINavigationController {
                if let viewController = navController.topViewController as? QRScannerController {
                    viewController.delegate = self
                }
            } else if let viewController = segue.destination as? QRScannerController {
                viewController.delegate = self
            }
        }
    }
    
    // update tableData so to make sure reloadData() works correctly
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == nameCell?.contentTextField {
            tableData[nameSection][0][PasswordEditorCellKey.content] = nameCell?.getContent()
        } else if textField == fillPasswordCell?.contentTextField {
            tableData[passwordSection][0][PasswordEditorCellKey.content] = fillPasswordCell?.getContent()
        }
    }
    
    // update tableData so to make sure reloadData() works correctly
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView == additionsCell?.contentTextView {
            tableData[additionsSection][0][PasswordEditorCellKey.content] = additionsCell?.getContent()
        }
    }
    
    func getNameURL() -> (String, URL) {
        let encodedName = (nameCell?.getContent()?.stringByAddingPercentEncodingForRFC3986())!
        let name = URL(string: encodedName)!.lastPathComponent
        let url = URL(string: encodedName)!.appendingPathExtension("gpg")
        return (name, url)
    }
    
    func checkName() -> Bool {
        // the name field should not be empty
        guard let name = nameCell?.getContent(), name.isEmpty == false else {
            Utils.alert(title: "Cannot Save", message: "Please fill in the name.", controller: self, completion: nil)
            return false
        }
        
        // the name should not start with /
        guard name.hasPrefix("/") == false else {
            Utils.alert(title: "Cannot Save", message: "Please remove the prefix \"/\" from your password name.", controller: self, completion: nil)
            return false
        }
        
        // the name field should be a valid url
        guard let path = name.stringByAddingPercentEncodingForRFC3986(),
            var passwordURL = URL(string: path) else {
            Utils.alert(title: "Cannot Save", message: "Password name is invalid.", controller: self, completion: nil)
            return false
        }
        
        // check whether we can parse the filename (be consistent with PasswordStore::addPasswordEntities)
        var previousPathLength = Int.max
        while passwordURL.path != "." {
            passwordURL = passwordURL.deletingLastPathComponent()
            if passwordURL.path != "." && passwordURL.path.count >= previousPathLength {
                Utils.alert(title: "Cannot Save", message: "Cannot parse the filename. Please check and simplify the password name.", controller: self, completion: nil)
                return false
            }
            previousPathLength = passwordURL.path.count
        }
        
        return true
    }
}
