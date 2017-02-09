//
//  GeneralSettingsTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 9/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit

class GeneralSettingsTableViewController: BasicStaticTableViewController {

    override func viewDidLoad() {
        navigationItemTitle = "General"
        tableData = [
            // section 0
            [[.type: CellDataType.segue, .title: "About Repository", .link: "showAboutRepositorySegue"],],
        ]
        super.viewDidLoad()
    }
}
