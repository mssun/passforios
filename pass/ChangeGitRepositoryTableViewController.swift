//
//  ChangeGitRepositoryTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 18/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import CoreData
import SVProgressHUD


class ChangeGitRepositoryTableViewController: UITableViewController {
    
    let userDefaults = UserDefaults.standard
    var gitRepositoryURL: String?
    
    @IBOutlet weak var gitRepositoryURLTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let url = userDefaults.string(forKey: "gitRepositoryURL") {
            gitRepositoryURLTextField.text = url
        } else {
            gitRepositoryURLTextField.text = "https://github.com/mssun/public-password-store.git"
        }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        gitRepositoryURLTextField.becomeFirstResponder()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "save" {
            gitRepositoryURL = gitRepositoryURLTextField.text!
        }
    }
}
