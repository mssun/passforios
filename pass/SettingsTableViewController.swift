//
//  SettingsTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 18/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import SVProgressHUD
import CoreData

class SettingsTableViewController: UITableViewController {
    
    @IBOutlet weak var gitRepositoryTableViewCell: UITableViewCell!
    
    @IBAction func cancel(segue: UIStoryboardSegue) {
    }
    
    @IBAction func save(segue: UIStoryboardSegue) {
        if let changeGitRepositoryTableViewController = segue.source as? ChangeGitRepositoryTableViewController {
            if let gitRepositoryURL = changeGitRepositoryTableViewController.gitRepositoryURL {
                if gitRepositoryTableViewCell.detailTextLabel?.text != gitRepositoryURL {
                    UserDefaults.standard.set(gitRepositoryURL, forKey: "gitRepositoryURL")
                    gitRepositoryTableViewCell.detailTextLabel?.text = gitRepositoryURL
                }
                SVProgressHUD.show(withStatus: "Cloning Remote Repository")
                DispatchQueue.global(qos: .userInitiated).async {
                    let ret = PasswordStore.shared.cloneRemoteRepo(remoteRepoURL: URL(string: gitRepositoryURL)!)
                    if ret {
                        DispatchQueue.main.async {
                            SVProgressHUD.dismiss()
                            SVProgressHUD.setMaximumDismissTimeInterval(1)
                            SVProgressHUD.showSuccess(withStatus: "Success")
                            NotificationCenter.default.post(Notification(name: Notification.Name("passwordUpdated")))
                        }
                    } else {
                        DispatchQueue.main.async {
                            SVProgressHUD.showError(withStatus: "Error")
                        }
                    }
                }
                
            }
        }

    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let url = UserDefaults.standard.string(forKey: "gitRepositoryURL") {
            gitRepositoryTableViewCell.detailTextLabel?.text = url
        } else {
            gitRepositoryTableViewCell.detailTextLabel?.text = "Not set"
        }
    }
}
