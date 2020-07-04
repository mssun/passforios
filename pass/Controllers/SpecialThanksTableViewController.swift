//
//  SpecialThanksTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 9/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit

class SpecialThanksTableViewController: BasicStaticTableViewController {
    let openSourceComponents = [
        [
            "Contributors".localize(),
            "https://github.com/mssun/passforios/graphs/contributors",
        ],
        [
            "Password Store",
            "https://passwordstore.org",
        ],
        [
            "Icon8",
            "https://icons8.com",
        ],
        [
            "FlatIcon",
            "https://www.flaticon.com",
        ],
    ]

    override func viewDidLoad() {
        tableData.append([])
        for item in openSourceComponents {
            tableData[0].append(
                [CellDataKey.action: "link", CellDataKey.title: item[0], CellDataKey.link: item[1]]
            )
        }
        super.viewDidLoad()
    }
}
