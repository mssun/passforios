//
//  SettingsSplitViewController.swift
//  pass
//
//  Created by Mingshen Sun on 6/21/17.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit

class SettingsSplitViewController: UISplitViewController, UISplitViewControllerDelegate {
    override func viewDidLoad() {
        self.delegate = self
        self.preferredDisplayMode = .allVisible
    }

    func splitViewController(
        _ splitViewController: UISplitViewController,
        collapseSecondary secondaryViewController: UIViewController,
        onto primaryViewController: UIViewController) -> Bool {
        // Return true to prevent UIKit from applying its default behavior
        return true
    }
}
