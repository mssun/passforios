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

    init(entries: [PasswordTableEntry] = []) {
        passwordTableEntries = entries
        filteredPasswordsTableEntries = passwordTableEntries
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredPasswordsTableEntries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "passwordTableViewCell", for: indexPath) as! PasswordTableViewCell

        let entry = filteredPasswordsTableEntries[indexPath.row]
        cell.configure(with: entry)

        return cell
    }

    func showTableEntries(matching text: String) {
        guard !text.isEmpty else {
            filteredPasswordsTableEntries = passwordTableEntries
            return
        }

        filteredPasswordsTableEntries = passwordTableEntries.filter { $0.match(text) }
    }
}
