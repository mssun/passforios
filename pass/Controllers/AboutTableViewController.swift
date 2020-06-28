//
//  AboutTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 8/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit

class AboutTableViewController: BasicStaticTableViewController {
    override func viewDidLoad() {
        tableData = [
            // section 0
            [[.title: "Website".localize(), .action: "link", .link: "https://github.com/mssun/pass-ios.git"],
             [.title: "Help".localize(), .action: "link", .link: "https://github.com/mssun/passforios/wiki"],
             [.title: "ContactDeveloper".localize(), .action: "link", .link: "mailto:developer@passforios.mssun.me?subject=Pass%20for%20iOS"]],

            // section 1,
            [[.title: "OpenSourceComponents".localize(), .action: "segue", .link: "showOpenSourceComponentsSegue"],
             [.title: "SpecialThanks".localize(), .action: "segue", .link: "showSpecialThanksSegue"]],
        ]
        super.viewDidLoad()
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == tableData.count - 1 {
            let view = UIView()
            let footerLabel = UILabel(frame: CGRect(x: 8, y: 15, width: tableView.frame.width, height: 60))
            footerLabel.numberOfLines = 0
            footerLabel.text = "PassForIos".localize() + " \(Bundle.main.releaseVersionNumber!) (\(Bundle.main.buildVersionNumber!))"
            footerLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
            footerLabel.textColor = UIColor.lightGray
            footerLabel.textAlignment = .center
            view.addSubview(footerLabel)
            return view
        }
        return nil
    }

    override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 1 {
            return "Acknowledgements".localize().uppercased()
        }
        return nil
    }
}
