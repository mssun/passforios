//
//  CommitLogsTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 28/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import ObjectiveGit
import passKit
import UIKit

class CommitLogsTableViewController: UITableViewController {
    var commits: [GTCommit] = []
    let passwordStore = PasswordStore.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(updateCommitLogs), name: .passwordStoreUpdated, object: nil)
        commits = getCommitLogs()
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = UITableView.automaticDimension
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        commits.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "commitLogCell", for: indexPath)
        let formatter = DateFormatter()
        formatter.dateStyle = DateFormatter.Style.medium
        formatter.timeStyle = .medium
        let dateString = formatter.string(from: commits[indexPath.row].commitDate)

        let author = cell.contentView.viewWithTag(200) as? UILabel
        let dateLabel = cell.contentView.viewWithTag(201) as? UILabel
        let messageLabel = cell.contentView.viewWithTag(202) as? UILabel
        author?.text = commits[indexPath.row].author?.name
        dateLabel?.text = dateString
        messageLabel?.text = commits[indexPath.row].message?.trimmed
        return cell
    }

    @objc
    func updateCommitLogs() {
        commits = getCommitLogs()
        tableView.reloadData()
    }

    private func getCommitLogs() -> [GTCommit] {
        do {
            return try passwordStore.getRecentCommits(count: 20)
        } catch {
            Utils.alert(title: "Error".localize(), message: error.localizedDescription, controller: self, completion: nil)
            return []
        }
    }
}
