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
    
    private static let openSourceComponents = [
        ["FavIcon",
         "https://github.com/bitserf/FavIcon",
         "https://github.com/bitserf/FavIcon/blob/master/LICENSE"],
        ["GopenPGP",
         "https://gopenpgp.org/",
         "https://github.com/ProtonMail/gopenpgp/blob/master/LICENSE"],
        ["KeychainAccess",
         "https://github.com/kishikawakatsumi/KeychainAccess",
         "https://github.com/kishikawakatsumi/KeychainAccess/blob/master/LICENSE"],
        ["ObjectiveGit",
         "https://github.com/libgit2/objective-git",
         "https://github.com/libgit2/objective-git/blob/master/LICENSE"],
        ["OneTimePassword",
         "https://github.com/mattrubin/OneTimePassword",
         "https://github.com/mattrubin/OneTimePassword/blob/develop/LICENSE.md"],
        ["SVProgressHUD",
         "https://github.com/SVProgressHUD/SVProgressHUD",
         "https://github.com/SVProgressHUD/SVProgressHUD/blob/master/LICENSE"],
        ["SwiftyUserDefaults",
         "https://github.com/radex/SwiftyUserDefaults",
         "https://github.com/radex/SwiftyUserDefaults/blob/master/LICENSE"],
        ["EFF's Wordlists",
         "https://www.eff.org/deeplinks/2016/07/new-wordlists-random-passphrases",
         "http://creativecommons.org/licenses/by/3.0"],
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        tableData.append([])
        for item in Self.openSourceComponents {
            tableData[0].append([
                .title: item[0],
                .action: "link",
                .link: item[1],
                .accessoryType: UITableViewCell.AccessoryType.detailDisclosureButton,
                .detailDisclosureAction: #selector(actOnDetailDisclosureButton(_:)),
                .detailDisclosureData: item[2]
            ])
        }
    }

    @objc func actOnDetailDisclosureButton(_ sender: Any?) {
        if let link = sender as? String, let url = URL(string: link) {
            let svc = SFSafariViewController(url: url, entersReaderIfAvailable: false)
            present(svc, animated: true)
        }
    }
}
