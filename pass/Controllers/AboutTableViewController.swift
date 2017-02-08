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
            [[CellDataKey.type: CellDataType.link, CellDataKey.title: "Website", CellDataKey.link: "https://github.com/mssun/pass-ios.git"],
             [CellDataKey.type: CellDataType.link, CellDataKey.title: "Contact Developer", CellDataKey.link: "https://mssun.me"],],
            
            // section 1,
            [[CellDataKey.type: CellDataType.segue, CellDataKey.title: "Open Source Components", CellDataKey.link: "showOpenSourceComponentsSegue"],
             [CellDataKey.type: CellDataType.segue, CellDataKey.title: "Special Thanks", CellDataKey.link: "showSpecialThanksSegue"],],
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

}
