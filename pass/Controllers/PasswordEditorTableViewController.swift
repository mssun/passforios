//
//  PasswordEditorTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 12/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
enum PasswordEditorCellType {
    case textFieldCell, textViewCell, fillPasswordCell, passwordLengthCell, deletePasswordCell
}

enum PasswordEditorCellKey {
    case type, title, content, placeholders
}

class PasswordEditorTableViewController: UITableViewController, FillPasswordTableViewCellDelegate, PasswordSettingSliderTableViewCellDelegate, UIGestureRecognizerDelegate {
    var navigationItemTitle: String?
    var password: Password?
    var tableData = [
        [Dictionary<PasswordEditorCellKey, Any>]
    ]()
    var sectionHeaderTitles = ["name", "password", "additions",""].map {$0.uppercased()}
    var sectionFooterTitles = ["", "", "Use \"key: value\" format for additional fields.", ""]
    let passwordSection = 1
    
    var fillPasswordCell: FillPasswordTableViewCell?
    var passwordLengthCell: SliderTableViewCell?
    var deletePasswordCell: UITableViewCell?
    
    override func loadView() {
        super.loadView()
        
        deletePasswordCell = UITableViewCell(style: .default, reuseIdentifier: "default")
        deletePasswordCell!.textLabel?.text = "Delete Password"
        deletePasswordCell!.textLabel?.textColor = Globals.red
        deletePasswordCell?.selectionStyle = .default
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = navigationItemTitle
        tableView.register(UINib(nibName: "TextFieldTableViewCell", bundle: nil), forCellReuseIdentifier: "textFieldCell")
        tableView.register(UINib(nibName: "TextViewTableViewCell", bundle: nil), forCellReuseIdentifier: "textViewCell")
        tableView.register(UINib(nibName: "FillPasswordTableViewCell", bundle: nil), forCellReuseIdentifier: "fillPasswordCell")
        tableView.register(UINib(nibName: "SliderTableViewCell", bundle: nil), forCellReuseIdentifier: "passwordLengthCell")
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 48
        self.tableView.sectionFooterHeight = UITableViewAutomaticDimension;
        self.tableView.estimatedSectionFooterHeight = 0;
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tableTapped))
        tapGesture.delegate = self
        tableView.addGestureRecognizer(tapGesture)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellData = tableData[indexPath.section][indexPath.row]
        
        switch cellData[PasswordEditorCellKey.type] as! PasswordEditorCellType {
        case .textViewCell:
            let cell = tableView.dequeueReusableCell(withIdentifier: "textViewCell", for: indexPath) as! ContentTableViewCell
            cell.setContent(content: cellData[PasswordEditorCellKey.content] as? String)
            return cell
        case .fillPasswordCell:
            fillPasswordCell = tableView.dequeueReusableCell(withIdentifier: "fillPasswordCell", for: indexPath) as? FillPasswordTableViewCell
            fillPasswordCell?.delegate = self
            fillPasswordCell?.setContent(content: cellData[PasswordEditorCellKey.content] as? String)
            return fillPasswordCell!
        case .passwordLengthCell:
            passwordLengthCell = tableView.dequeueReusableCell(withIdentifier: "passwordLengthCell", for: indexPath) as? SliderTableViewCell
            passwordLengthCell?.reset(title: "Length", minimumValue: Globals.passwordMinimumLength, maximumValue: Globals.passwordMaximumLength, defaultValue: Globals.passwordDefaultLength)
            passwordLengthCell?.delegate = self
            return passwordLengthCell!
        case .deletePasswordCell:
            return deletePasswordCell!
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: "textFieldCell", for: indexPath) as! ContentTableViewCell
            cell.setContent(content: cellData[PasswordEditorCellKey.content] as? String)
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 44
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return tableData.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableData[section].count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionHeaderTitles[section]
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sectionFooterTitles[section]
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.cellForRow(at: indexPath) == deletePasswordCell {
            let alert = UIAlertController(title: "Delete Password?", message: nil, preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "Delete", style: UIAlertActionStyle.destructive, handler: {[unowned self] (action) -> Void in
                self.performSegue(withIdentifier: "deletePasswordSegue", sender: self)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler:nil))
            self.present(alert, animated: true, completion: nil)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // generate password, copy to pasteboard, and set the cell
    func generateAndCopyPassword() {
        // insert the length slider if not existed
        if passwordLengthCell == nil {
            let row = tableData[passwordSection].count
            tableData[passwordSection].append([.type: PasswordEditorCellType.passwordLengthCell, .title: "passwordlength"])
            let indexPath = IndexPath(row: row, section: passwordSection)
            tableView.insertRows(at: [indexPath], with: UITableViewRowAnimation.automatic)
        }
        let length = passwordLengthCell?.roundedValue ?? Globals.passwordDefaultLength
        let plainPassword = Utils.generatePassword(length: length)
        Utils.copyToPasteboard(textToCopy: plainPassword)
        fillPasswordCell?.setContent(content: plainPassword)
    }
    
    func tableTapped(tap: UITapGestureRecognizer) {
        let location = tap.location(in: self.tableView)
        let path = self.tableView.indexPathForRow(at: location)
        if path?.section != passwordSection, tableData[passwordSection].count > 1 {
            // remove password settings (e.g., sliders)
            let row = tableData[passwordSection].count
            passwordLengthCell = nil
            tableData[passwordSection].removeLast(row - 1)
            let indexPaths = (1...row-1).map{IndexPath(row: $0, section: passwordSection)}
            print(indexPaths)
            tableView.deleteRows(at: indexPaths, with: UITableViewRowAnimation.automatic)
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if (gestureRecognizer is UITapGestureRecognizer) {
            // so that the tap gesture could be passed by
            return true
        } else {
            return false
        }
    }
}
