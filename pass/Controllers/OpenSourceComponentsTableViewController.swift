//
//  OpenSourceComponentsTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 9/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit

class OpenSourceComponentsTableViewController: BasicStaticTableViewController {
    let openSourceComponents = [
        ["PasscodeLock",
         "https://github.com/zahlz/SwiftPasscodeLock",
         "https://github.com/zahlz/SwiftPasscodeLock/blob/master/LICENSE.txt"],
        ["ObjectiveGit",
         "https://github.com/libgit2/objective-git",
         "https://github.com/libgit2/objective-git/blob/master/LICENSE"],
        ["SwiftyUserDefaults",
         "https://github.com/radex/SwiftyUserDefaults",
         "https://github.com/radex/SwiftyUserDefaults/blob/master/LICENSE"],
        ["SVProgressHUD",
         "https://github.com/SVProgressHUD/SVProgressHUD",
         "https://github.com/SVProgressHUD/SVProgressHUD/blob/master/LICENSE.txt"],
        ["Result",
         "https://github.com/antitypical/Result",
         "https://github.com/antitypical/Result/blob/master/LICENSE"],
    ]
    
    override func viewDidLoad() {
        tableData.append([])
        for item in openSourceComponents {
            tableData[0].append(
                [CellDataKey.type: CellDataType.link, CellDataKey.title: item[0], CellDataKey.link: item[1], CellDataKey.accessoryType: UITableViewCellAccessoryType.detailDisclosureButton, CellDataKey.detailDisclosureAction: #selector(actOnDetailDisclosureButton(_:)), CellDataKey.detailDisclosureData: item[2]]
            )
        }
        navigationItemTitle = "Open Source Components"
        super.viewDidLoad()
    }
    
    func actOnDetailDisclosureButton(_ sender: Any?) {
        if let link = sender as? String {
            UIApplication.shared.open(URL(string: link)!, options: [:], completionHandler: nil)
        }
    }

}
