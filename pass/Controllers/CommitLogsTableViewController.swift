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
        self.tableView.estimatedRowHeight = 50
        self.tableView.rowHeight = UITableViewAutomaticDimension
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return commits.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "commitLogCell", for: indexPath)
        let formatter = DateFormatter()
        formatter.dateStyle = DateFormatter.Style.medium
        formatter.timeStyle = .medium
        let dateString = formatter.string(from: commits[indexPath.row].commitDate)
        
        let author = cell.contentView.viewWithTag(100) as? UILabel
        let dateLabel = cell.contentView.viewWithTag(101) as? UILabel
        let messageLabel = cell.contentView.viewWithTag(102) as? UILabel
        author?.text = commits[indexPath.row].author?.name
        dateLabel?.text = dateString
        messageLabel?.text = commits[indexPath.row].message?.trimmingCharacters(in: .whitespacesAndNewlines)
        return cell
    }
}
