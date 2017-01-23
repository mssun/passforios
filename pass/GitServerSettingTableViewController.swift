//
//  GitServerSettingTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 21/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import SwiftyUserDefaults

class GitServerSettingTableViewController: UITableViewController {

    @IBOutlet weak var gitRepositoryURLTextField: UITextField!
    
    @IBOutlet weak var usernameTextField: UITextField!
    
    @IBOutlet weak var passwordTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let url = Defaults[.gitRepositoryURL] {
            gitRepositoryURLTextField.text = url.absoluteString
        }
        usernameTextField.text = Defaults[.gitRepositoryUsername]
        passwordTextField.text = Defaults[.gitRepositoryPassword]
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        gitRepositoryURLTextField.becomeFirstResponder()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
    }
}
