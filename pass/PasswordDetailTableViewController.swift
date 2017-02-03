//
//  PasswordDetailTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 2/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit

class PasswordDetailTableViewController: UITableViewController {
    var passwordEntity: PasswordEntity?

    struct FormCell {
        var title: String
        var content: String
    }
    
    var formData = [[FormCell]]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UINib(nibName: "LabelTableViewCell", bundle: nil), forCellReuseIdentifier: "labelCell")
        let password = passwordEntity!.decrypt()!
        formData.append([])
        if let username = password.additions["Username"] {
            formData[0].append(FormCell(title: "username", content: username))
        }
        formData[0].append(FormCell(title: "password", content: password.password))
    }


    override func numberOfSections(in tableView: UITableView) -> Int {
        return formData.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return formData[section].count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "labelCell", for: indexPath) as! LabelTableViewCell
        cell.titleLabel.text = formData[indexPath.section][indexPath.row].title
        cell.contentLabel.text = formData[indexPath.section][indexPath.row].content
        return cell
    }
    
    override func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
        if action == #selector(copy(_:)) {
            UIPasteboard.general.string = formData[indexPath.section][indexPath.row].content
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
