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
        ["Password Store",
         "http://passwordstore.org"],
        ["Icon8",
         "http://icons8.com"],
        ]
    
    override func viewDidLoad() {
        tableData.append([])
        for item in openSourceComponents {
            tableData[0].append(
                [CellDataKey.type: CellDataType.link, CellDataKey.title: item[0], CellDataKey.link: item[1]]
            )
        }
        navigationItemTitle = "Special Thanks"
        super.viewDidLoad()
    }}
