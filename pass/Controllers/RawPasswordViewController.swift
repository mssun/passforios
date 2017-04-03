//
//  RawPasswordViewController.swift
//  pass
//
//  Created by Mingshen Sun on 31/3/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit

class RawPasswordViewController: UIViewController {

    @IBOutlet weak var rawPasswordTextView: UITextView!
    var password: Password?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Raw"
        rawPasswordTextView.text = password?.plainText
    }
}
