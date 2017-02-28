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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        commits = PasswordStore.shared.getRecentCommits(count: 20)
        navigationItem.title = "Recent Commit Logs"
        navigationItem.leftBarButtonItem?.title = "About"
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
        cell.textLabel?.text = dateString
        cell.detailTextLabel?.text = commits[indexPath.row].message
        return cell
    }
}
