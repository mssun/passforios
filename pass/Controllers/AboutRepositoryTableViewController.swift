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
        let fm = FileManager.default
        var size = UInt64(0)
        do {
            size = try fm.allocatedSizeOfDirectoryAtURL(directoryURL: PasswordStore.shared.storeURL)
        } catch {
            print(error)
        }
        let formatted = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: ByteCountFormatter.CountStyle.file)
        tableData = [
            // section 0
            [[.type: CellDataType.detail, .title: "Passwords", .detailText: String(passwordEntities.count)],
             [.type: CellDataType.detail, .title: "Size", .detailText: formatted],
             [.type: CellDataType.detail, .title: "Last Synced", .detailText: Utils.getLastUpdatedTimeString()],
             ],
        ]
        tableView.reloadData()
    }

}
