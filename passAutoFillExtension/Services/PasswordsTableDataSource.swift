//
//  PasswordsTableDataSource.swift
//  passAutoFillExtension
//
//  Created by Sun, Mingshen on 12/31/20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import UIKit
import passKit

class PasswordsTableDataSource: NSObject, UITableViewDataSource {
    var passwordTableEntries: [PasswordTableEntry]
    var filteredPasswordsTableEntries: [PasswordTableEntry]
    var suggestedPasswordsTableEntries: [PasswordTableEntry]
    var otherPasswordsTableEntries: [PasswordTableEntry]

    var showSuggestion: Bool = false

    init(entries: [PasswordTableEntry] = []) {
        passwordTableEntries = entries
        filteredPasswordsTableEntries = passwordTableEntries
        suggestedPasswordsTableEntries = []
        otherPasswordsTableEntries = []
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        if !showSuggestion {
            return 1
        } else {
            return 2
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if !showSuggestion {
            return filteredPasswordsTableEntries.count
        }

        if section == 0 {
            return suggestedPasswordsTableEntries.count
        } else {
            return otherPasswordsTableEntries.count
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if suggestedPasswordsTableEntries.isEmpty {
            return nil
        }

        if !showSuggestion {
            return "All Passwords"
        }

        if section == 0 {
            return "Suggested Passwords"
        } else {
            return "Other Passwords"
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "passwordTableViewCell", for: indexPath) as! PasswordTableViewCell

        var entry: PasswordTableEntry!
        if !showSuggestion {
            entry = filteredPasswordsTableEntries[indexPath.row]
            cell.configure(with: entry)
            return cell
        }

        if indexPath.section == 0 {
            entry = suggestedPasswordsTableEntries[indexPath.row]
        } else {
            entry = otherPasswordsTableEntries[indexPath.row]
        }
        cell.configure(with: entry)

        return cell
    }

    func showTableEntries(matching text: String) {
        guard !text.isEmpty else {
            filteredPasswordsTableEntries = passwordTableEntries
            showSuggestion = true
            return
        }

        filteredPasswordsTableEntries = passwordTableEntries.filter { $0.match(text) }
        showSuggestion = false
    }

    func showTableEntriesWithSuggestion(matching text: String) {
        for entry in passwordTableEntries {
            if entry.match(text) {
                suggestedPasswordsTableEntries.append(entry)
            } else {
                otherPasswordsTableEntries.append(entry)
            }
        }
        showSuggestion = !suggestedPasswordsTableEntries.isEmpty
    }
}
