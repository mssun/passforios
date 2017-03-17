//
//  CommitLogsTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 28/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import ObjectiveGit

class CommitLogsTableViewController: UITableViewController {
    var commits: [GTCommit] = []
    let passwordStore = PasswordStore.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        commits = passwordStore.getRecentCommits(count: 20)
        navigationItem.title = "Recent Commit Logs"
        navigationController!.navigationBar.topItem!.title = "About"
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return commits.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "commitLogCell", for: indexPath)
        let formatter = DateFormatter()
        formatter.dateStyle = DateFormatter.Style.short
        formatter.timeStyle = .none
        let dateString = formatter.string(from: commits[indexPath.row].commitDate)
        let dateLabel = cell.viewWithTag(101) as! UILabel
        let messageLabel = cell.viewWithTag(102) as! UILabel
        dateLabel.text = dateString
        messageLabel.text = commits[indexPath.row].message
        return cell
    }
}
