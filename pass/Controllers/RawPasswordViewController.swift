//
//  RawPasswordViewController.swift
//  pass
//
//  Created by Mingshen Sun on 31/3/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import passKit
import UIKit

class RawPasswordViewController: UIViewController {
    @IBOutlet var rawPasswordTextView: UITextView!
    var password: Password?

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = password?.name
        rawPasswordTextView.textContainer.lineFragmentPadding = 0
        rawPasswordTextView.textContainerInset = .zero
        rawPasswordTextView.text = password?.plainText
        rawPasswordTextView.textColor = Colors.label
    }
}
