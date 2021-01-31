//
//  PasswordNavigationDataSource.swift
//  pass
//
//  Created by Sun, Mingshen on 1/16/21.
//  Copyright © 2021 Bob Sun. All rights reserved.
//

import passKit
import UIKit

struct Section {
    var title: String
    var entries: [PasswordTableEntry]
}

class PasswordNavigationDataSource: NSObject, UITableViewDataSource {
    var sections: [Section]
    var filteredSections: [Section]

    var isSearchActive = false
    let hideSectionHeaderThreshold = 6

    init(entries: [PasswordTableEntry] = []) {
        self.sections = buildSections(from: entries)
        self.filteredSections = sections
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredSections[section].entries.count
    }

    func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        showSectionTitles() ? filteredSections[section].title : nil
    }

    func tableView(_: UITableView, sectionForSectionIndexTitle _: String, at index: Int) -> Int {
        index
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "passwordTableViewCell", for: indexPath) as! PasswordTableViewCell
        let entry = getPasswordTableEntry(at: indexPath)
        cell.configure(with: entry)
        return cell
    }

    func numberOfSections(in _: UITableView) -> Int {
        filteredSections.count
    }

    func sectionIndexTitles(for _: UITableView) -> [String]? {
        showSectionTitles() ? filteredSections.map(\.title) : nil
    }

    func showSectionTitles() -> Bool {
        !isSearchActive && filteredSections.count > hideSectionHeaderThreshold
    }

    func getPasswordTableEntry(at indexPath: IndexPath) -> PasswordTableEntry {
        filteredSections[indexPath.section].entries[indexPath.row]
    }

    func showTableEntries(matching text: String) {
        guard !text.isEmpty else {
            filteredSections = sections
            return
        }

        filteredSections = sections.map { section in
            let entries = section.entries.filter { $0.match(text) }
            return Section(title: section.title, entries: entries)
        }
        .filter { !$0.entries.isEmpty }
    }

    func showUnsyncedTableEntries() {
        filteredSections = sections.map { section in
            let entries = section.entries.filter { !$0.synced }
            return Section(title: section.title, entries: entries)
        }
        .filter { !$0.entries.isEmpty }
    }
}

private func buildSections(from entries: [PasswordTableEntry]) -> [Section] {
    let collation = UILocalizedIndexedCollation.current()
    let sectionTitles = collation.sectionIndexTitles
    var sections = [Section]()

    // initialize all sections
    for titleNumber in 0 ..< sectionTitles.count {
        sections.append(Section(title: sectionTitles[titleNumber], entries: [PasswordTableEntry]()))
    }

    // put entries into sections
    for entry in entries {
        let sectionNumber = collation.section(for: entry, collationStringSelector: #selector(getter: PasswordTableEntry.title))
        sections[sectionNumber].entries.append(entry)
    }

    // sort each list and set sectionTitles
    for titleNumber in 0 ..< sectionTitles.count {
        let entriesToSort = sections[titleNumber].entries
        let sortedEntries = collation.sortedArray(from: entriesToSort, collationStringSelector: #selector(getter: PasswordTableEntry.title))
        sections[titleNumber].entries = sortedEntries as! [PasswordTableEntry]
    }

    // only keep non-empty sections
    return sections.filter { !$0.entries.isEmpty }
}
