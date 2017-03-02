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
        let indicatorLable = UILabel(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 21))
        indicatorLable.center = CGPoint(x: view.frame.size.width / 2, y: view.frame.size.height * 0.382 + 22)
        indicatorLable.backgroundColor = UIColor.clear
        indicatorLable.textColor = UIColor.gray
        indicatorLable.text = "calculating"
        indicatorLable.textAlignment = .center
        indicatorLable.font = UIFont.preferredFont(forTextStyle: .footnote)
        let indicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        indicator.center = CGPoint(x: view.frame.size.width / 2, y: view.frame.size.height * 0.382)
        indicator.startAnimating()
        tableView.addSubview(indicator)
        tableView.addSubview(indicatorLable)
        
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
                indicator.stopAnimating()
                indicatorLable.isHidden = true
                self?.tableView.reloadData()
            }
        }
    }

}
