//
//  PasswordDetailViewController.swift
//  pass
//
//  Created by Mingshen Sun on 18/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import SwiftyUserDefaults

class PasswordDetailViewController: UIViewController {

    @IBOutlet weak var passwordTextView: UITextView!
    var passwordEntity: PasswordEntity?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let password = passwordEntity!.decrypt()!
        passwordTextView.text = password.password
    }
}
