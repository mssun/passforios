//
//  AutoCellHeightUITableViewController.swift
//  pass
//
//  Created by Danny Moesch on 17.02.19.
//  Copyright © 2019 Bob Sun. All rights reserved.
//

import UIKit

class AutoCellHeightUITableViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.estimatedRowHeight = 170
        tableView.rowHeight = UITableView.automaticDimension
    }
}
