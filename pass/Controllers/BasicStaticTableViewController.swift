//
//  BasicTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 9/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit

enum CellDataType {
    case link, segue, empty
}

enum CellDataKey {
    case type, title, link, footer
}

class BasicStaticTableViewController: UITableViewController {
    var tableData = [[Dictionary<CellDataKey, Any>]]()
    var navigationItemTitle: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = navigationItemTitle
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return tableData.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableData[section].count
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        let cellData = tableData[indexPath.section][indexPath.row]
        cell.textLabel?.text = cellData[CellDataKey.title] as? String
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let cellData = tableData[indexPath.section][indexPath.row]
        let cellDataType = cellData[CellDataKey.type] as? CellDataType
        switch cellDataType! {
        case .segue:
            let link = cellData[CellDataKey.link] as? String
            performSegue(withIdentifier: link!, sender: self)
        case .link:
            let link = cellData[CellDataKey.link] as? String
            UIApplication.shared.open(URL(string: link!)!, options: [:], completionHandler: nil)
        default:
            break
        }
    }
}
