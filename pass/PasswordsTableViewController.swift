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
    
    @IBAction func refreshPasswords(_ sender: UIBarButtonItem) {
        DispatchQueue.global(qos: .userInitiated).async {
            if PasswordStore.shared.pullRepository() {
                print("pull success")
                self.passwordEntities = PasswordStore.shared.fetchPasswordEntityCoreData()
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
        tableView.tableHeaderView = searchController.searchBar
        tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: UITableViewScrollPosition.top, animated: false)
    }
    
    func filterContentForSearchText(searchText: String, scope: String = "All") {
        filteredPasswordEntities = passwordEntities!.filter { password in
            return password.name!.lowercased().contains(searchText.lowercased())
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
        if searchController.isActive && searchController.searchBar.text != "" {
            return filteredPasswordEntities.count
        }
        return passwordEntities!.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "passwordTableViewCell", for: indexPath)
        let password: PasswordEntity
        if searchController.isActive && searchController.searchBar.text != "" {
            password = filteredPasswordEntities[indexPath.row]
        } else {
            password = passwordEntities![indexPath.row]
        }
        cell.textLabel?.text = password.name
        return cell
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showPasswordDetail" {
            if let viewController = segue.destination as? PasswordDetailViewController {
                let selectedIndex = self.tableView.indexPath(for: sender as! UITableViewCell)!
                let password: PasswordEntity
                if searchController.isActive && searchController.searchBar.text != "" {
                    password = filteredPasswordEntities[selectedIndex.row]
                } else {
                    password = passwordEntities![selectedIndex.row]
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

