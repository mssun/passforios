//
//  PasswordCell.swift
//  passAutoFillExtension
//
//  Created by Sun, Mingshen on 12/31/20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import passKit

class PasswordTableViewCell: UITableViewCell {
    func configure(with entry: PasswordTableEntry) {
        if entry.passwordEntity.synced {
            textLabel?.text = entry.title
        } else {
            textLabel?.text = "↻ \(entry.title)"
        }
        accessoryType = .none
        detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .footnote)
        detailTextLabel?.text = entry.categoryText
    }
}
