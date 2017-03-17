//
//  PasswordsViewController.swift
//  pass
//
//  Created by Mingshen Sun on 3/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import SVProgressHUD
import SwiftyUserDefaults
import PasscodeLock

enum PasswordsTableEntryType {
    case password, dir
}

struct PasswordsTableEntry {
    var title: String
    var isDir: Bool
    var passwordEntity: PasswordEntity?
}

class PasswordsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITabBarControllerDelegate {
    private var passwordsTableEntries: [PasswordsTableEntry] = []
    private var filteredPasswordsTableEntries: [PasswordsTableEntry] = []
    private var parentPasswordEntity: PasswordEntity? = nil
    let passwordStore = PasswordStore.shared
    
    private var tapTabBarTime: TimeInterval = 0

    var sections : [(index: Int, length :Int, title: String)] = Array()
    var searchActive : Bool = false
    lazy var searchController: UISearchController = {
        let uiSearchController = UISearchController(searchResultsController: nil)
        uiSearchController.searchResultsUpdater = self
        uiSearchController.dimsBackgroundDuringPresentation = false
        uiSearchController.searchBar.isTranslucent = false
        uiSearchController.searchBar.backgroundColor = UIColor.gray
        uiSearchController.searchBar.sizeToFit()
        return uiSearchController
    }()
    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(PasswordsViewController.handleRefresh(_:)), for: UIControlEvents.valueChanged)
        return refreshControl
    }()
    lazy var searchBarView: UIView = {
        let uiView = UIView(frame: CGRect(x: 0, y: 64, width: UIScreen.main.bounds.width, height: 44))
        uiView.addSubview(self.searchController.searchBar)
        return uiView
    }()
    lazy var backUIBarButtonItem: UIBarButtonItem = {
        let backUIBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(self.backAction(_:)))
        return backUIBarButtonItem
    }()

    @IBOutlet weak var tableView: UITableView!
    
    private func initPasswordsTableEntries(parent: PasswordEntity?) {
        passwordsTableEntries.removeAll()
        filteredPasswordsTableEntries.removeAll()
        var passwordEntities = [PasswordEntity]()
        if Defaults[.isShowFolderOn] {
            passwordEntities = self.passwordStore.fetchPasswordEntityCoreData(parent: parent)
        } else {
            passwordEntities = self.passwordStore.fetchPasswordEntityCoreData(withDir: false)
            
        }
        passwordsTableEntries = passwordEntities.map {
            PasswordsTableEntry(title: $0.name!, isDir: $0.isDir, passwordEntity: $0)
        }
        parentPasswordEntity = parent
    }
    
    @IBAction func cancelAddPassword(segue: UIStoryboardSegue) {
        
    }
    @IBAction func saveAddPassword(segue: UIStoryboardSegue) {
        if let controller = segue.source as? AddPasswordTableViewController {
            SVProgressHUD.setDefaultMaskType(.black)
            SVProgressHUD.setDefaultStyle(.light)
            SVProgressHUD.show(withStatus: "Saving")
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try self.passwordStore.add(password: controller.password!, progressBlock: { progress in
                        DispatchQueue.main.async {
                            SVProgressHUD.showProgress(progress, status: "Encrypting")
                        }
                    })
                    
                    DispatchQueue.main.async {
                        SVProgressHUD.showSuccess(withStatus: "Done")
                        SVProgressHUD.dismiss(withDelay: 1)
                        NotificationCenter.default.post(Notification(name: Notification.Name("passwordUpdated")))
                    }
                } catch {
                    DispatchQueue.main.async {
                        Utils.alert(title: "Error", message: error.localizedDescription, controller: self, completion: nil)
                    }
                }
            }
        }
    }
    
    func syncPasswords() {
        SVProgressHUD.setDefaultMaskType(.black)
        SVProgressHUD.setDefaultStyle(.light)
        SVProgressHUD.show(withStatus: "Sync Password Store")
        let numberOfUnsyncedPasswords = self.passwordStore.getNumberOfUnsyncedPasswords()
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            do {
                try self.passwordStore.pullRepository(transferProgressBlock: {(git_transfer_progress, stop) in
                    DispatchQueue.main.async {
                        SVProgressHUD.showProgress(Float(git_transfer_progress.pointee.received_objects)/Float(git_transfer_progress.pointee.total_objects), status: "Pull Remote Repository")
                    }
                })
                if numberOfUnsyncedPasswords > 0 {
                    try self.passwordStore.pushRepository(transferProgressBlock: {(current, total, bytes, stop) in
                        DispatchQueue.main.async {
                            SVProgressHUD.showProgress(Float(current)/Float(total), status: "Push Remote Repository")
                        }
                    })
                }
                DispatchQueue.main.async {
                    self.passwordStore.updatePasswordEntityCoreData()
                    self.initPasswordsTableEntries(parent: nil)
                    self.reloadTableView(data: self.passwordsTableEntries)
                    self.passwordStore.setAllSynced()
                    self.setNavigationItemTitle()
                    Defaults[.lastUpdatedTime] = Date()
                    Defaults[.gitRepositoryPasswordAttempts] = 0
                    SVProgressHUD.showSuccess(withStatus: "Done")
                    SVProgressHUD.dismiss(withDelay: 1)
                }
            } catch {
                DispatchQueue.main.async {
                    Utils.alert(title: "Error", message: error.localizedDescription, controller: self, completion: nil)
                }
            }
        }
    }
    
    private func addNotificationObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(PasswordsViewController.actOnPasswordUpdatedNotification), name: NSNotification.Name(rawValue: "passwordUpdated"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PasswordsViewController.actOnPasswordStoreErasedNotification), name: NSNotification.Name(rawValue: "passwordStoreErased"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PasswordsViewController.actOnSearchNotification), name: NSNotification.Name(rawValue: "search"), object: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setNavigationItemTitle()
        initPasswordsTableEntries(parent: nil)
        addNotificationObservers()
        generateSections(item: passwordsTableEntries)
        tabBarController!.delegate = self
        tableView.delegate = self
        tableView.dataSource = self
        definesPresentationContext = true
        view.addSubview(searchBarView)
        tableView.insertSubview(refreshControl, at: 0)
        SVProgressHUD.setDefaultMaskType(.black)
        updateRefreshControlTitle()
        tableView.register(UINib(nibName: "PasswordWithFolderTableViewCell", bundle: nil), forCellReuseIdentifier: "passwordWithFolderTableViewCell")
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
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction(_:)))
        longPressGestureRecognizer.minimumPressDuration = 0.6
        if Defaults[.isShowFolderOn] {
            let cell = tableView.dequeueReusableCell(withIdentifier: "passwordTableViewCell", for: indexPath)
            
            let entry = getPasswordEntry(by: indexPath)
            if !entry.isDir {
                if entry.passwordEntity!.synced {
                    cell.textLabel?.text = entry.title
                } else {
                    cell.textLabel?.text = "↻ \(entry.title)"
                }
                
                cell.addGestureRecognizer(longPressGestureRecognizer)
                cell.accessoryType = .none
                cell.detailTextLabel?.text = ""
            } else {
                cell.textLabel?.text = "\(entry.title)"
                cell.accessoryType = .disclosureIndicator
                cell.detailTextLabel?.text = "\(entry.passwordEntity?.children?.count ?? 0)"
            }
            return cell
        } else {
            let passwordWithFolderCell = tableView.dequeueReusableCell(withIdentifier: "passwordWithFolderTableViewCell", for: indexPath) as! PasswordWithFolderTableViewCell
            let entry = getPasswordEntry(by: indexPath)
            if entry.passwordEntity!.synced {
                passwordWithFolderCell.passwordLabel?.text = entry.title
            } else {
                passwordWithFolderCell.passwordLabel?.text = "↻ \(entry.title)"
            }
            passwordWithFolderCell.folderLabel.text = entry.passwordEntity?.getCategoryText()
            passwordWithFolderCell.addGestureRecognizer(longPressGestureRecognizer)
            return passwordWithFolderCell
        }

    }
    
    private func getPasswordEntry(by indexPath: IndexPath) -> PasswordsTableEntry {
        var entry: PasswordsTableEntry
        let index = sections[indexPath.section].index + indexPath.row
        if searchController.isActive && searchController.searchBar.text != "" {
            entry = filteredPasswordsTableEntries[index]
        } else {
            entry = passwordsTableEntries[index]
        }
        return entry
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let entry = getPasswordEntry(by: indexPath)
        if !entry.isDir {
            let segueIdentifier = "showPasswordDetail"
            let sender = tableView.cellForRow(at: indexPath)
            if shouldPerformSegue(withIdentifier: segueIdentifier, sender: sender) {
                performSegue(withIdentifier: segueIdentifier, sender: sender)
            }
        } else {
            tableView.deselectRow(at: indexPath, animated: true)
            searchController.isActive = false
            initPasswordsTableEntries(parent: entry.passwordEntity)
            reloadTableView(data: passwordsTableEntries)
        }
    }
    
    func backAction(_ sender: Any?) {
        guard Defaults[.isShowFolderOn] else { return }
        initPasswordsTableEntries(parent: parentPasswordEntity?.parent)
        reloadTableView(data: passwordsTableEntries)
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
        guard self.passwordStore.privateKey != nil else {
            Utils.alert(title: "Cannot Copy Password", message: "PGP Key is not set. Please set your PGP Key first.", controller: self, completion: nil)
            return
        }
        let password = getPasswordEntry(by: indexPath).passwordEntity!
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        var passphrase = ""
        if Defaults[.isRememberPassphraseOn] && self.passwordStore.pgpKeyPassphrase != nil  {
            passphrase = self.passwordStore.pgpKeyPassphrase!
            self.decryptThenCopyPassword(passwordEntity: password, passphrase: passphrase)
        } else {
            let alert = UIAlertController(title: "Passphrase", message: "Please fill in the passphrase of your PGP secret key.", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {_ in
                passphrase = alert.textFields!.first!.text!
                self.decryptThenCopyPassword(passwordEntity: password, passphrase: passphrase)
            }))
            alert.addTextField(configurationHandler: {(textField: UITextField!) in
                textField.text = ""
                textField.isSecureTextEntry = true
            })
            self.present(alert, animated: true, completion: nil)
        }

    }
    
    func decryptThenCopyPassword(passwordEntity: PasswordEntity, passphrase: String) {
        SVProgressHUD.setDefaultMaskType(.black)
        SVProgressHUD.setDefaultStyle(.dark)
        SVProgressHUD.show(withStatus: "Decrypting")
        DispatchQueue.global(qos: .userInteractive).async {
            var decryptedPassword: Password?
            do {
                decryptedPassword = try passwordEntity.decrypt(passphrase: passphrase)!
                DispatchQueue.main.async {
                    Utils.copyToPasteboard(textToCopy: decryptedPassword?.password)
                    SVProgressHUD.showSuccess(withStatus: "Password copied, and will be cleared in 45 seconds.")
                    SVProgressHUD.dismiss(withDelay: 0.6)
                }
            } catch {
                print(error)
                DispatchQueue.main.async {
                    Utils.alert(title: "Error", message: error.localizedDescription, controller: self, completion: nil)
                }
            }
        }
    }
    
    func generateSections(item: [PasswordsTableEntry]) {
        sections.removeAll()
        guard item.count != 0 else {
            return
        }
        var index = 0
        for i in 0 ..< item.count {
            let title = item[index].title.uppercased()
            let commonPrefix = item[i].title.commonPrefix(with: title, options: .caseInsensitive)
            if commonPrefix.characters.count == 0 {
                let firstCharacter = title[title.startIndex]
                let newSection = (index: index, length: i - index, title: "\(firstCharacter)")
                sections.append(newSection)
                index = i
            }
        }
        let title = item[index].title.uppercased()
        let firstCharacter = title[title.startIndex]
        let newSection = (index: index, length: item.count - index, title: "\(firstCharacter)")
        sections.append(newSection)
    }
    
    func actOnPasswordUpdatedNotification() {
        initPasswordsTableEntries(parent: nil)
        reloadTableView(data: passwordsTableEntries)
        setNavigationItemTitle()
    }
    
    private func setNavigationItemTitle() {
        var title = ""
        if parentPasswordEntity != nil {
            title = parentPasswordEntity!.name!
        } else {
            title = "Password Store"
        }
        let numberOfUnsynced = self.passwordStore.getNumberOfUnsyncedPasswords()
        if numberOfUnsynced == 0 {
            navigationItem.title = "\(title)"
        } else {
            navigationItem.title = "\(title) (\(numberOfUnsynced))"
        }
    }
    
    func actOnPasswordStoreErasedNotification() {
        initPasswordsTableEntries(parent: nil)
        reloadTableView(data: passwordsTableEntries)
        setNavigationItemTitle()
    }
    
    func actOnSearchNotification() {
        searchController.searchBar.becomeFirstResponder()
    }

    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "showPasswordDetail" {
            guard self.passwordStore.privateKey != nil else {
                Utils.alert(title: "Cannot Show Password", message: "PGP Key is not set. Please set your PGP Key first.", controller: self, completion: nil)
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
                let passwordEntity = getPasswordEntry(by: selectedIndexPath).passwordEntity!
                viewController.passwordEntity = passwordEntity
            }
        }
    }
    
    func filterContentForSearchText(searchText: String, scope: String = "All") {
        filteredPasswordsTableEntries = passwordsTableEntries.filter { entry in
            return entry.title.lowercased().contains(searchText.lowercased())
        }
        if searchController.isActive && searchController.searchBar.text != "" {
            reloadTableView(data: filteredPasswordsTableEntries)
        } else {
            reloadTableView(data: passwordsTableEntries)
        }
    }
    
    func updateRefreshControlTitle() {
        var atribbutedTitle = "Pull to Sync Password Store"
        atribbutedTitle = "Last Synced: \(Utils.getLastUpdatedTimeString())"
        refreshControl.attributedTitle = NSAttributedString(string: atribbutedTitle)
    }
    
    func reloadTableView(data: [PasswordsTableEntry]) {
        setNavigationItemTitle()
        if parentPasswordEntity != nil {
            navigationItem.leftBarButtonItem = backUIBarButtonItem
        } else {
            navigationItem.leftBarButtonItem = nil
        }
        generateSections(item: data)
        tableView.reloadData()
        updateRefreshControlTitle()
    }
    
    func handleRefresh(_ refreshControl: UIRefreshControl) {
        syncPasswords()
        refreshControl.endRefreshing()
    }
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        if viewController == self.navigationController {
            let currentTime = Date().timeIntervalSince1970
            let duration = currentTime - self.tapTabBarTime
            self.tapTabBarTime = currentTime
            if duration < 0.35 {
                let topIndexPath = IndexPath(row: 0, section: 0)
                tableView.scrollToRow(at: topIndexPath, at: .bottom, animated: true)
                self.tapTabBarTime = 0
                return
            }
            backAction(self)
        }
    }
}

extension PasswordsViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        filterContentForSearchText(searchText: searchController.searchBar.text!)
    }
}
