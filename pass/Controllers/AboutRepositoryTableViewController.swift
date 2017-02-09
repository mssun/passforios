//
//  AboutRepositoryTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 9/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit

class AboutRepositoryTableViewController: BasicStaticTableViewController {

    override func viewDidLoad() {
        navigationItemTitle = "About Repository"
        super.viewDidLoad()
        let passwordEntities = PasswordStore.shared.fetchPasswordEntityCoreData()
        tableData = [
            // section 0
            [[.type: CellDataType.detail, .title: "Passwords", .detailText: String(passwordEntities.count)],
             [.type: CellDataType.detail, .title: "Last Updated", .detailText: Utils.getLastUpdatedTimeString()],
             ],
        ]
        tableView.reloadData()
    }

}
