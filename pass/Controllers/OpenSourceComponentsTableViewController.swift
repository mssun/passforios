//
//  OpenSourceComponentsTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 9/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import SafariServices

class OpenSourceComponentsTableViewController: BasicStaticTableViewController {
    let openSourceComponents = [
        ["FavIcon",
         "https://github.com/bitserf/FavIcon",
         "https://github.com/bitserf/FavIcon/blob/master/LICENSE"],
        ["PasscodeLock",
         "https://github.com/zahlz/SwiftPasscodeLock",
         "https://github.com/zahlz/SwiftPasscodeLock/blob/master/LICENSE.txt"],
        ["ObjectiveGit",
         "https://github.com/libgit2/objective-git",
         "https://github.com/libgit2/objective-git/blob/master/LICENSE"],
        ["ObjectivePGP",
         "https://github.com/krzyzanowskim/ObjectivePGP",
         "https://github.com/krzyzanowskim/ObjectivePGP/blob/master/LICENSE.txt"],
        ["SwiftyUserDefaults",
         "https://github.com/radex/SwiftyUserDefaults",
         "https://github.com/radex/SwiftyUserDefaults/blob/master/LICENSE"],
        ["SVProgressHUD",
         "https://github.com/SVProgressHUD/SVProgressHUD",
         "https://github.com/SVProgressHUD/SVProgressHUD/blob/master/LICENSE.txt"],
    ]
    
    override func viewDidLoad() {
        tableData.append([])
        for item in openSourceComponents {
            tableData[0].append(
                [CellDataKey.title: item[0], CellDataKey.action: "link", CellDataKey.link: item[1], CellDataKey.accessoryType: UITableViewCellAccessoryType.detailDisclosureButton, CellDataKey.detailDisclosureAction: #selector(actOnDetailDisclosureButton(_:)), CellDataKey.detailDisclosureData: item[2]]
            )
        }
        navigationItemTitle = "Open Source Components"
        super.viewDidLoad()
    }
    
    func actOnDetailDisclosureButton(_ sender: Any?) {
        if let link = sender as? String {
            let svc = SFSafariViewController(url: URL(string: link)!, entersReaderIfAvailable: false)
            self.present(svc, animated: true, completion: nil)
        }
    }

}
