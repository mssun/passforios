//
//  AboutRepositoryTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 9/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit

class AboutRepositoryTableViewController: BasicStaticTableViewController {
    
    var needRefresh = false
    var indicatorLabel: UILabel!
    var indicator: UIActivityIndicatorView!

    override func viewDidLoad() {
        navigationItemTitle = "About Repository"
        super.viewDidLoad()
            
        indicatorLabel = UILabel(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 21))
        indicatorLabel.center = CGPoint(x: view.frame.size.width / 2, y: view.frame.size.height * 0.382 + 22)
        indicatorLabel.backgroundColor = UIColor.clear
        indicatorLabel.textColor = UIColor.gray
        indicatorLabel.text = "calculating"
        indicatorLabel.textAlignment = .center
        indicatorLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        indicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        indicator.center = CGPoint(x: view.frame.size.width / 2, y: view.frame.size.height * 0.382)
        tableView.addSubview(indicator)
        tableView.addSubview(indicatorLabel)
        
        setTableData()
        addNotificationObservers()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if needRefresh {
            indicatorLabel.text = "reloading"
            setTableData()
        }
    }
    
    private func setTableData() {
        
        // clear current contents (if any)
        self.tableData.removeAll(keepingCapacity: true)
        self.tableView.reloadData()
        indicatorLabel.isHidden = false
        indicator.startAnimating()
        
        // reload the table
        DispatchQueue.global(qos: .userInitiated).async {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = NumberFormatter.Style.decimal
            let fm = FileManager.default
            
            let passwordEntities = PasswordStore.shared.fetchPasswordEntityCoreData(withDir: false)
            let numberOfPasswords = numberFormatter.string(from: NSNumber(value: passwordEntities.count))!
            
            var size = UInt64(0)
            do {
                if fm.fileExists(atPath: PasswordStore.shared.storeURL.path) {
                    size = try fm.allocatedSizeOfDirectoryAtURL(directoryURL: PasswordStore.shared.storeURL)
                }
            } catch {
                print(error)
            }
            let sizeOfRepository = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: ByteCountFormatter.CountStyle.file)
            
            let numberOfCommits = PasswordStore.shared.storeRepository?.numberOfCommits(inCurrentBranch: NSErrorPointer(nilLiteral: ())) ?? 0
            let numberOfCommitsString = numberFormatter.string(from: NSNumber(value: numberOfCommits))!
            
            
            DispatchQueue.main.async { [weak self] in
                let type = UITableViewCellAccessoryType.none
                self?.tableData = [
                    // section 0
                    [[.style: CellDataStyle.value1, .accessoryType: type, .title: "Passwords", .detailText: numberOfPasswords],
                     [.style: CellDataStyle.value1, .accessoryType: type, .title: "Size", .detailText: sizeOfRepository],                     [.style: CellDataStyle.value1, .accessoryType: type, .title: "Unsynced", .detailText: String(PasswordStore.shared.getNumberOfUnsyncedPasswords())],
                     [.style: CellDataStyle.value1, .accessoryType: type, .title: "Last Synced", .detailText: Utils.getLastUpdatedTimeString()],
                     [.style: CellDataStyle.value1, .accessoryType: type, .title: "Commits", .detailText: numberOfCommitsString],
                     [.title: "Commit Logs", .action: "segue", .link: "showCommitLogsSegue"],
                     ],
                ]
                self?.indicator.stopAnimating()
                self?.indicatorLabel.isHidden = true
                self?.tableView.reloadData()
            }
        }
    }
        
    private func addNotificationObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(setNeedRefresh), name: NSNotification.Name(rawValue: "passwordUpdated"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(setNeedRefresh), name: NSNotification.Name(rawValue: "passwordStoreErased"), object: nil)
    }
    
    func setNeedRefresh() {
        needRefresh = true
    }
}
