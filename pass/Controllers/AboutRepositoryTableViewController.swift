//
//  AboutRepositoryTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 9/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import passKit

class AboutRepositoryTableViewController: BasicStaticTableViewController {

    private var needRefresh = false
    private var indicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        return indicator
    }()
    private let passwordStore = PasswordStore.shared

    override func viewDidLoad() {
        super.viewDidLoad()

        indicator.center = CGPoint(x: view.bounds.midX, y: view.bounds.height * 0.382)
        tableView.addSubview(indicator)

        setTableData()

        // all password store updates (including erase, discard) will trigger the refresh
        NotificationCenter.default.addObserver(self, selector: #selector(setNeedRefresh), name: .passwordStoreUpdated, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if needRefresh {
            setTableData()
            needRefresh = false
        }
    }

    private func setTableData() {

        // clear current contents (if any)
        self.tableData.removeAll(keepingCapacity: true)
        self.tableView.reloadData()
        indicator.startAnimating()

        // reload the table
        DispatchQueue.global(qos: .userInitiated).async {
            let passwords = self.numberOfPasswordsString()
            let size = self.sizeOfRepositoryString()
            let localCommits = self.numberOfLocalCommitsString()
            let lastSynced = self.lastSyncedTimeString()
            let commits = self.numberOfCommitsString()

            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                let type = UITableViewCellAccessoryType.none
                strongSelf.tableData = [
                    // section 0
                    [[.style: CellDataStyle.value1, .accessoryType: type, .title: "Passwords", .detailText: passwords],
                     [.style: CellDataStyle.value1, .accessoryType: type, .title: "Size", .detailText: size],
                     [.style: CellDataStyle.value1, .accessoryType: type, .title: "Local Commits", .detailText: localCommits],
                     [.style: CellDataStyle.value1, .accessoryType: type, .title: "Last Synced", .detailText: lastSynced],
                     [.style: CellDataStyle.value1, .accessoryType: type, .title: "Commits", .detailText: commits],
                     [.title: "Commit Logs", .action: "segue", .link: "showCommitLogsSegue"],
                     ],
                ]
                strongSelf.indicator.stopAnimating()
                strongSelf.tableView.reloadData()
            }
        }
    }

    private func numberOfPasswordsString() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = NumberFormatter.Style.decimal
        return formatter.string(from: NSNumber(value: self.passwordStore.numberOfPasswords)) ?? ""
    }

    private func sizeOfRepositoryString() -> String {
        return ByteCountFormatter.string(fromByteCount: Int64(self.passwordStore.sizeOfRepositoryByteCount), countStyle: ByteCountFormatter.CountStyle.file)
    }

    private func numberOfLocalCommitsString() -> String {
        return String(passwordStore.numberOfLocalCommits)
    }

    private func lastSyncedTimeString() -> String {
        guard let date = self.passwordStore.lastSyncedTime else {
            return "Oops! Sync again?"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func numberOfCommitsString() -> String {
        return String(passwordStore.numberOfCommits)
    }

    @objc func setNeedRefresh() {
        needRefresh = true
    }
}
