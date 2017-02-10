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
            let passwordEntities = PasswordStore.shared.fetchPasswordEntityCoreData()
            let fm = FileManager.default
            var size = UInt64(0)
            do {
                size = try fm.allocatedSizeOfDirectoryAtURL(directoryURL: PasswordStore.shared.storeURL)
            } catch {
                print(error)
            }

            DispatchQueue.main.async { [weak self] in
                let formatted = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: ByteCountFormatter.CountStyle.file)
                self?.tableData = [
                    // section 0
                    [[.style: CellDataStyle.value1, .accessoryType: UITableViewCellAccessoryType.none, .title: "Passwords", .detailText: String(passwordEntities.count)],
                     [.style: CellDataStyle.value1, .accessoryType: UITableViewCellAccessoryType.none, .title: "Size", .detailText: formatted],
                     [.style: CellDataStyle.value1, .accessoryType: UITableViewCellAccessoryType.none, .title: "Last Synced", .detailText: Utils.getLastUpdatedTimeString()],
                     ],
                ]
                indicator.stopAnimating()
                indicatorLable.isHidden = true
                self?.tableView.reloadData()
            }
        }
    }

}
