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
            [[.type: CellDataType.link, .title: "Website", .link: "https://github.com/mssun/pass-ios.git"],
             [.type: CellDataType.link, .title: "Contact Developer", .link: "mailto:bob@mssun.me?subject=passforiOS"],],
            
            // section 1,
            [[.type: CellDataType.segue, .title: "Open Source Components", .link: "showOpenSourceComponentsSegue"],
             [.type: CellDataType.segue, .title: "Special Thanks", .link: "showSpecialThanksSegue"],],
        ]
        navigationItemTitle = "About"
        super.viewDidLoad()
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == tableData.count - 1 {
            let view = UIView()
            let footerLabel = UILabel(frame: CGRect(x: 8, y: 15, width: tableView.frame.width, height: 60))
            footerLabel.numberOfLines = 0
            footerLabel.text = "pass for iOS\nBob Sun"
            footerLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
            footerLabel.textColor = UIColor.lightGray
            footerLabel.textAlignment = .center
            view.addSubview(footerLabel)
            return view
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 1 {
            let view = UITableViewHeaderFooterView()
            view.textLabel?.text = "Acknowledgements"
            return view
        }
        return nil
    }

}
