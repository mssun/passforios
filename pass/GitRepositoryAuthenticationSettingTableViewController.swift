//
//  GitRepositoryAuthenticationSettingTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 25/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit

class GitRepositoryAuthenticationSettingTableViewController: UITableViewController {
    
    var selectedMethod: String?
    
    @IBOutlet weak var sshKeyCell: UITableViewCell!
    @IBOutlet weak var passwordCell: UITableViewCell!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Auth Method"
        switch selectedMethod! {
        case "Password":
            passwordCell.accessoryType = UITableViewCellAccessoryType.checkmark
        case "SSH Key":
            sshKeyCell.accessoryType = UITableViewCellAccessoryType.checkmark
        default:
            break
        }
    }
    
}
