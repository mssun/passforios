//
//  PasswordTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 18/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import Result
import SVProgressHUD


class PasswordsTableViewController: UITableViewController {
    private var passwordEntities: [PasswordEntity]?
    var filteredPasswordEntities = [PasswordEntity]()
    let searchController = UISearchController(searchResultsController: nil)
    var sections : [(index: Int, length :Int, title: String)] = Array()
    
    @IBAction func refreshPasswords(_ sender: UIBarButtonItem) {
        SVProgressHUD.setDefaultMaskType(.black)
        SVProgressHUD.show(withStatus: "Pull Remote Repository")
        DispatchQueue.global(qos: .userInitiated).async {
            if PasswordStore.shared.pullRepository(transferProgressBlock: {(git_transfer_progress, stop) in
                DispatchQueue.main.async {
                SVProgressHUD.showProgress(Float(git_transfer_progress.pointee.received_objects)/Float(git_transfer_progress.pointee.total_objects), status: "Pull Remote Repository")
                }
            }) {
                DispatchQueue.main.async {
                    SVProgressHUD.showSuccess(withStatus: "Done")
                    SVProgressHUD.dismiss(withDelay: 1)
                }
                print("pull success")
                self.passwordEntities = PasswordStore.shared.fetchPasswordEntityCoreData()
                self.generateSections(item: self.passwordEntities!)
                self.tableView.reloadData()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        passwordEntities = PasswordStore.shared.fetchPasswordEntityCoreData()
        NotificationCenter.default.addObserver(self, selector: #selector(PasswordsTableViewController.actOnPasswordUpdatedNotification), name: NSNotification.Name(rawValue: "passwordUpdated"), object: nil)
        searchController.searchResultsUpdater = self
        searchController.dimsBackgroundDuringPresentation = false
        definesPresentationContext = true
        // tableView.setContentOffset(CGPoint(x: 0, y: 44), animated: false)
        generateSections(item: passwordEntities!)
        tableView.tableHeaderView = searchController.searchBar
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func generateSections(item: [PasswordEntity]) {
        sections.removeAll()
        if item.count == 0 {
            return
        }
        var index = 0
        for i in 0 ..< item.count {
            let name = item[index].name!.uppercased()
            let commonPrefix = item[i].name!.commonPrefix(with: name, options: .caseInsensitive)
            if commonPrefix.characters.count == 0 {
                let firstCharacter = name[name.startIndex]
                let newSection = (index: index, length: i - index, title: "\(firstCharacter)")
                print("index: \(index), length: \(newSection.length), title: \(newSection.title)")
                sections.append(newSection)
                index = i
            }
        }
        let name = item[index].name!.uppercased()
        let firstCharacter = name[name.startIndex]
        let newSection = (index: index, length: item.count - index, title: "\(firstCharacter)")
        sections.append(newSection)
    }
    
    func filterContentForSearchText(searchText: String, scope: String = "All") {
        filteredPasswordEntities = passwordEntities!.filter { password in
            return password.name!.lowercased().contains(searchText.lowercased())
        }
        if searchController.isActive && searchController.searchBar.text != "" {
            generateSections(item: filteredPasswordEntities)
        } else {
            generateSections(item: passwordEntities!)
        }
        tableView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    func actOnPasswordUpdatedNotification() {
        passwordEntities = PasswordStore.shared.fetchPasswordEntityCoreData()
        self.tableView.reloadData()
        print("actOnPasswordUpdatedNotification")
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//        if searchController.isActive && searchController.searchBar.text != "" {
//            return filteredPasswordEntities.count
//        }
//        return passwordEntities!.count
        return sections[section].length
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "passwordTableViewCell", for: indexPath)
        var password: PasswordEntity
        let index = sections[indexPath.section].index + indexPath.row
        if searchController.isActive && searchController.searchBar.text != "" {
            password = filteredPasswordEntities[index]
        } else {
            password = passwordEntities![index]
        }
        cell.textLabel?.text = password.name
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }
    
    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return sections.map { $0.title }
    }
    
    override func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        return index
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showPasswordDetail" {
            if let viewController = segue.destination as? PasswordDetailViewController {
                let selectedIndexPath = self.tableView.indexPath(for: sender as! UITableViewCell)!
                let index = sections[selectedIndexPath.section].index + selectedIndexPath.row
                let password: PasswordEntity
                if searchController.isActive && searchController.searchBar.text != "" {
                    password = filteredPasswordEntities[index]
                } else {
                    password = passwordEntities![index]
                }
                viewController.passwordEntity = password
                viewController.navigationItem.title = password.name
            }
        }
    }
    
}

extension PasswordsTableViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        filterContentForSearchText(searchText: searchController.searchBar.text!)
    }
}

