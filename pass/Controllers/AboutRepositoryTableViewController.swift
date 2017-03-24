//
//  AboutRepositoryTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 9/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit

class AboutRepositoryTableViewController: BasicStaticTableViewController {
    
    private var needRefresh = false
    private var indicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        return indicator
    }()
    private let passwordStore = PasswordStore.shared

    override func viewDidLoad() {
        navigationItemTitle = "About Repository"
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
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = NumberFormatter.Style.decimal
            
            let numberOfPasswordsString = numberFormatter.string(from: NSNumber(value: self.passwordStore.numberOfPasswords))!
            let sizeOfRepositoryString = ByteCountFormatter.string(fromByteCount: Int64(self.passwordStore.sizeOfRepositoryByteCount), countStyle: ByteCountFormatter.CountStyle.file)
            
            let numberOfCommits = self.passwordStore.storeRepository?.numberOfCommits(inCurrentBranch: NSErrorPointer(nilLiteral: ())) ?? 0
            let numberOfCommitsString = numberFormatter.string(from: NSNumber(value: numberOfCommits))!
            
            DispatchQueue.main.async { [weak self] in
                let type = UITableViewCellAccessoryType.none
                self?.tableData = [
                    // section 0
                    [[.style: CellDataStyle.value1, .accessoryType: type, .title: "Passwords", .detailText: numberOfPasswordsString],
                     [.style: CellDataStyle.value1, .accessoryType: type, .title: "Size", .detailText: sizeOfRepositoryString],
                     [.style: CellDataStyle.value1, .accessoryType: type, .title: "Local Commits", .detailText: String(self?.passwordStore.numberOfLocalCommits() ?? 0)],
                     [.style: CellDataStyle.value1, .accessoryType: type, .title: "Last Synced", .detailText: Utils.getLastUpdatedTimeString()],
                     [.style: CellDataStyle.value1, .accessoryType: type, .title: "Commits", .detailText: numberOfCommitsString],
                     [.title: "Commit Logs", .action: "segue", .link: "showCommitLogsSegue"],
                     ],
                ]
                self?.indicator.stopAnimating()
                self?.tableView.reloadData()
            }
        }
    }
    
    func setNeedRefresh() {
        needRefresh = true
    }
}
