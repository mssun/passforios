//
//  PasswordDetailTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 2/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit

class PasswordDetailTableViewController: UITableViewController, UIGestureRecognizerDelegate {
    var passwordEntity: PasswordEntity?

    struct TableCell {
        var title: String
        var content: String
    }
    
    struct TableSection {
        var title: String
        var item: Array<TableCell>
    }
    
    var tableData = Array<TableSection>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UINib(nibName: "LabelTableViewCell", bundle: nil), forCellReuseIdentifier: "labelCell")
        let password = passwordEntity!.decrypt()!
        
        var tableDataIndex = 0
        tableData.append(TableSection(title: "", item: []))
        if let username = password.additions["Username"] {
            tableData[tableDataIndex].item.append(TableCell(title: "username", content: username))
            password.additions.removeValue(forKey: "Username")
        }
        tableData[tableDataIndex].item.append(TableCell(title: "password", content: password.password))

        if password.additions.count > 0 {
            tableData.append(TableSection(title: "additions", item: []))
            tableDataIndex += 1
            for (key, value) in password.additions {
                tableData[tableDataIndex].item.append(TableCell(title: key, content: value))
            }
        }
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(PasswordDetailTableViewController.tapMenu(recognizer:)))
        tableView.addGestureRecognizer(tapGesture)
        tapGesture.delegate = self
    }
    
    func tapMenu(recognizer: UITapGestureRecognizer)  {
        print("tap")
        if recognizer.state == UIGestureRecognizerState.ended {
            let tapLocation = recognizer.location(in: self.tableView)
            if let tapIndexPath = self.tableView.indexPathForRow(at: tapLocation) {
                print(tapIndexPath)
                if let tappedCell = self.tableView.cellForRow(at: tapIndexPath) as? LabelTableViewCell {
                    tappedCell.becomeFirstResponder()
                    let menuController = UIMenuController.shared
                    menuController.setTargetRect(tappedCell.contentLabel.frame, in: tappedCell.contentLabel.superview!)
                    menuController.setMenuVisible(true, animated: true)
                }
            }
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return tableData.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableData[section].item.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "labelCell", for: indexPath) as! LabelTableViewCell
        cell.titleLabel.text = tableData[indexPath.section].item[indexPath.row].title
        cell.contentLabel.text = tableData[indexPath.section].item[indexPath.row].content
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return tableData[section].title
    }
    
    override func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
        if action == #selector(copy(_:)) {
            UIPasteboard.general.string = tableData[indexPath.section].item[indexPath.row].content
        }
    }
    
    override func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return action == #selector(UIResponderStandardEditActions.copy(_:))
    }
    
    override func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 52
    }

}
