//
//  AboutRepositoryTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 9/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import passKit
import UIKit

class AboutRepositoryTableViewController: BasicStaticTableViewController {
    private static let VALUE_NOT_AVAILABLE = "ValueNotAvailable".localize()

    private var needRefresh = false
    private var indicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .gray)
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
        tableData.removeAll(keepingCapacity: true)
        tableView.reloadData()
        indicator.startAnimating()

        // reload the table
        DispatchQueue.global(qos: .userInitiated).async {
            let passwords = self.numberOfPasswordsString()
            let size = self.sizeOfRepositoryString()
            let localCommits = String(self.passwordStore.numberOfLocalCommits)
            let lastSynced = self.lastSyncedTimeString()
            let commits = self.numberOfCommitsString()

            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                let type = UITableViewCell.AccessoryType.none
                strongSelf.tableData = [
                    // section 0
                    [
                        [.style: CellDataStyle.value1, .accessoryType: type, .title: "Passwords".localize(), .detailText: passwords],
                        [.style: CellDataStyle.value1, .accessoryType: type, .title: "Size".localize(), .detailText: size],
                        [.style: CellDataStyle.value1, .accessoryType: type, .title: "LocalCommits".localize(), .detailText: localCommits],
                        [.style: CellDataStyle.value1, .accessoryType: type, .title: "LastSynced".localize(), .detailText: lastSynced],
                        [.style: CellDataStyle.value1, .accessoryType: type, .title: "Commits".localize(), .detailText: commits],
                        [.title: "CommitLogs".localize(), .action: "segue", .link: "showCommitLogsSegue"],
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
        return formatter.string(from: NSNumber(value: passwordStore.numberOfPasswords)) ?? ""
    }

    private func sizeOfRepositoryString() -> String {
        ByteCountFormatter.string(fromByteCount: Int64(passwordStore.sizeOfRepositoryByteCount), countStyle: ByteCountFormatter.CountStyle.file)
    }

    private func lastSyncedTimeString() -> String {
        guard let date = passwordStore.lastSyncedTime else {
            return "SyncAgain?".localize()
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func numberOfCommitsString() -> String {
        if let numberOfCommits = passwordStore.numberOfCommits {
            return String(numberOfCommits)
        }
        return Self.VALUE_NOT_AVAILABLE
    }

    @objc
    func setNeedRefresh() {
        needRefresh = true
    }
}
