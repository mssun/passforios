//
//  PasswordTableViewCell.swift
//  pass
//
//  Created by Sun, Mingshen on 12/31/20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import passKit

class PasswordTableViewCell: UITableViewCell {
    func configure(with entry: PasswordTableEntry) {
        textLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        textLabel?.text = entry.passwordEntity.synced ? entry.title : "↻ \(entry.title)"
        textLabel?.adjustsFontForContentSizeCategory = true

        accessoryType = .none
        detailTextLabel?.textColor = UIColor.lightGray
        detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .footnote)
        detailTextLabel?.adjustsFontForContentSizeCategory = true
        detailTextLabel?.text = entry.categoryText

        if entry.isDir {
            accessoryType = .disclosureIndicator
            textLabel?.font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .medium)
            detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .body)
            detailTextLabel?.text = "\(entry.passwordEntity.children?.count ?? 0)"
        }
    }
}
