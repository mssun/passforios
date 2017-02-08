//
//  PasswordsViewController.swift
//  pass
//
//  Created by Mingshen Sun on 3/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import Result
import SVProgressHUD
import SwiftyUserDefaults
import PasscodeLock

class PasswordsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private var passwordEntities: [PasswordEntity]?
    var filteredPasswordEntities = [PasswordEntity]()
    var sections : [(index: Int, length :Int, title: String)] = Array()
    var searchActive : Bool = false
    let searchController = UISearchController(searchResultsController: nil)
    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(PasswordsViewController.handleRefresh(_:)), for: UIControlEvents.valueChanged)
        return refreshControl
    }()
    let searchBarView = UIView(frame: CGRect(x: 0, y: 64, width: UIScreen.main.bounds.width, height: 44))

    @IBOutlet weak var tableView: UITableView!
    
    func syncPasswords() {
        SVProgressHUD.setDefaultMaskType(.black)
        SVProgressHUD.setDefaultStyle(.light)
        SVProgressHUD.show(withStatus: "Sync Password Store")
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            do {
                try PasswordStore.shared.pullRepository(transferProgressBlock: {(git_transfer_progress, stop) in
                    DispatchQueue.main.async {
                        SVProgressHUD.showProgress(Float(git_transfer_progress.pointee.received_objects)/Float(git_transfer_progress.pointee.total_objects), status: "Pull Remote Repository")
                    }
                })
                DispatchQueue.main.async {
                    self.passwordEntities = PasswordStore.shared.fetchPasswordEntityCoreData()
                    self.reloadTableView(data: self.passwordEntities!)
                    Defaults[.lastUpdatedTime] = Date()
                    SVProgressHUD.showSuccess(withStatus: "Done")
                    SVProgressHUD.dismiss(withDelay: 1)
                }
            } catch {
                DispatchQueue.main.async {
                    SVProgressHUD.showError(withStatus: error.localizedDescription)
                    SVProgressHUD.dismiss(withDelay: 3)
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if PasscodeLockRepository().hasPasscode {
            let passcodeEnterViewController = PasscodeLockViewController(state: .enter, configuration: Globals.passcodeConfiguration)
            UIApplication.shared.keyWindow?.rootViewController?.present(passcodeEnterViewController, animated: true, completion: nil)
        }
        passwordEntities = PasswordStore.shared.fetchPasswordEntityCoreData()
        NotificationCenter.default.addObserver(self, selector: #selector(PasswordsViewController.actOnPasswordUpdatedNotification), name: NSNotification.Name(rawValue: "passwordUpdated"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PasswordsViewController.actOnPasswordStoreErasedNotification), name: NSNotification.Name(rawValue: "passwordStoreErased"), object: nil)

        generateSections(item: passwordEntities!)
        tableView.delegate = self
        tableView.dataSource = self
        searchController.searchResultsUpdater = self
        searchController.dimsBackgroundDuringPresentation = false
        searchController.searchBar.isTranslucent = false
        searchController.searchBar.backgroundColor = UIColor.gray
        searchController.searchBar.sizeToFit()
        definesPresentationContext = true
        searchBarView.addSubview(searchController.searchBar)
        view.addSubview(searchBarView)
        tableView.insertSubview(refreshControl, at: 0)
        SVProgressHUD.setDefaultMaskType(.black)
        updateRefreshControlTitle()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let path = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: path, animated: false)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        searchBarView.frame = CGRect(x: 0, y: navigationController!.navigationBar.bounds.size.height + UIApplication.shared.statusBarFrame.height, width: UIScreen.main.bounds.width, height: 44)
        searchController.searchBar.sizeToFit()
    }
    
     func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].length
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "passwordTableViewCell", for: indexPath)
        var password: PasswordEntity
        let index = sections[indexPath.section].index + indexPath.row
        if searchController.isActive && searchController.searchBar.text != "" {
            password = filteredPasswordEntities[index]
        } else {
            password = passwordEntities![index]
        }
        cell.textLabel?.text = password.name
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction(_:)))
        longPressGestureRecognizer.minimumPressDuration = 0.6
        cell.addGestureRecognizer(longPressGestureRecognizer)
        return cell
    }
    
    func longPressAction(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == UIGestureRecognizerState.began {
            let touchPoint = gesture.location(in: tableView)
            if let indexPath = tableView.indexPathForRow(at: touchPoint) {
                copyToPasteboard(from: indexPath)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }

    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return sections.map { $0.title }
    }

    func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        return index
    }
    
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        copyToPasteboard(from: indexPath)
    }
    
    func copyToPasteboard(from indexPath: IndexPath) {
        let index = sections[indexPath.section].index + indexPath.row
        let password: PasswordEntity
        if searchController.isActive && searchController.searchBar.text != "" {
            password = filteredPasswordEntities[index]
        } else {
            password = passwordEntities![index]
        }
        do {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            let decryptedPassword = try password.decrypt()!
            UIPasteboard.general.string = decryptedPassword.password
            generator.impactOccurred()
            SVProgressHUD.setDefaultMaskType(.clear)
            SVProgressHUD.setDefaultStyle(.dark)
            SVProgressHUD.showInfo(withStatus: "Password Copied")
            SVProgressHUD.dismiss(withDelay: 0.6)
        } catch {
            print(error)
        }
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
                sections.append(newSection)
                index = i
            }
        }
        let name = item[index].name!.uppercased()
        let firstCharacter = name[name.startIndex]
        let newSection = (index: index, length: item.count - index, title: "\(firstCharacter)")
        sections.append(newSection)
    }
    
    func actOnPasswordUpdatedNotification() {
        passwordEntities = PasswordStore.shared.fetchPasswordEntityCoreData()
        reloadTableView(data: passwordEntities!)
    }
    
    func actOnPasswordStoreErasedNotification() {
        passwordEntities = PasswordStore.shared.fetchPasswordEntityCoreData()
        reloadTableView(data: passwordEntities!)
    }

    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "showPasswordDetail" {
            if Defaults[.pgpKeyID]  == "" {
                let alert = UIAlertController(title: "Cannot Show Password", message: "PGP Key is not set. Please set your PGP Key first.", preferredStyle: UIAlertControllerStyle.alert)
                alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                self.present(alert, animated: true, completion: nil)
                if let s = sender as? UITableViewCell {
                    let selectedIndexPath = tableView.indexPath(for: s)!
                    tableView.deselectRow(at: selectedIndexPath, animated: true)
                }
                return false
            }
        }
        return true
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showPasswordDetail" {
            if let viewController = segue.destination as? PasswordDetailTableViewController {
                let selectedIndexPath = self.tableView.indexPath(for: sender as! UITableViewCell)!
                let index = sections[selectedIndexPath.section].index + selectedIndexPath.row
                let passwordEntity: PasswordEntity
                if searchController.isActive && searchController.searchBar.text != "" {
                    passwordEntity = filteredPasswordEntities[index]
                } else {
                    passwordEntity = passwordEntities![index]
                }
                viewController.passwordEntity = passwordEntity
                let passwordCategoryEntities = PasswordStore.shared.fetchPasswordCategoryEntityCoreData(password: passwordEntity)
                viewController.passwordCategoryEntities = passwordCategoryEntities
            }
        }
    }
    
    func filterContentForSearchText(searchText: String, scope: String = "All") {
        filteredPasswordEntities = passwordEntities!.filter { password in
            return password.name!.lowercased().contains(searchText.lowercased())
        }
        if searchController.isActive && searchController.searchBar.text != "" {
            reloadTableView(data: filteredPasswordEntities)
        } else {
            reloadTableView(data: passwordEntities!)
        }
    }
    
    func updateRefreshControlTitle() {
        var atribbutedTitle = "Pull to Sync Password Store"
        if let lastUpdatedTime = Defaults[.lastUpdatedTime] {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .short
            let dateString = formatter.string(from: lastUpdatedTime)
            atribbutedTitle = "Last Sync: \(dateString)"
        }
        refreshControl.attributedTitle = NSAttributedString(string: atribbutedTitle)
    }
    
    func reloadTableView (data: [PasswordEntity]) {
        generateSections(item: data)
        tableView.reloadData()
        updateRefreshControlTitle()
    }
    
    func handleRefresh(_ refreshControl: UIRefreshControl) {
        syncPasswords()
        refreshControl.endRefreshing()
    }
}

extension PasswordsViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        filterContentForSearchText(searchText: searchController.searchBar.text!)
    }
}
