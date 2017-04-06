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

fileprivate class PasswordsTableEntry : NSObject {
    var title: String
    var isDir: Bool
    var passwordEntity: PasswordEntity?
    init(title: String, isDir: Bool, passwordEntity: PasswordEntity?) {
        self.title = title
        self.isDir = isDir
        self.passwordEntity = passwordEntity
    }
}

class PasswordsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITabBarControllerDelegate, UISearchBarDelegate {
    private var passwordsTableEntries: [PasswordsTableEntry] = []
    private var passwordsTableAllEntries: [PasswordsTableEntry] = []
    private var filteredPasswordsTableEntries: [PasswordsTableEntry] = []
    private var parentPasswordEntity: PasswordEntity? = nil
    private let passwordStore = PasswordStore.shared
    
    private var tapTabBarTime: TimeInterval = 0

    private var sections = [(title: String, entries: [PasswordsTableEntry])]()
    
    private var searchActive : Bool = false
    
    private lazy var searchController: UISearchController = {
        let uiSearchController = UISearchController(searchResultsController: nil)
        uiSearchController.searchResultsUpdater = self
        uiSearchController.dimsBackgroundDuringPresentation = false
        uiSearchController.searchBar.isTranslucent = false
        uiSearchController.searchBar.backgroundColor = UIColor.gray
        uiSearchController.searchBar.sizeToFit()
        return uiSearchController
    }()
    private lazy var syncControl: UIRefreshControl = {
        let syncControl = UIRefreshControl()
        syncControl.addTarget(self, action: #selector(handleRefresh(_:)), for: UIControlEvents.valueChanged)
        return syncControl
    }()
    private lazy var searchBarView: UIView = {
        let uiView = UIView(frame: CGRect(x: 0, y: 64, width: self.view.bounds.width, height: 44))
        uiView.addSubview(self.searchController.searchBar)
        return uiView
    }()
    private lazy var backUIBarButtonItem: UIBarButtonItem = {
        let backUIBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(self.backAction(_:)))
        return backUIBarButtonItem
    }()
    
    private lazy var transitionFromRight: CATransition = {
        let transition = CATransition()
        transition.type = kCATransitionPush
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        transition.fillMode = kCAFillModeForwards
        transition.duration = 0.25
        transition.subtype = kCATransitionFromRight
        return transition
    }()
    
    private lazy var transitionFromLeft: CATransition = {
        let transition = CATransition()
        transition.type = kCATransitionPush
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        transition.fillMode = kCAFillModeForwards
        transition.duration = 0.25
        transition.subtype = kCATransitionFromLeft
        return transition
    }()

    @IBOutlet weak var tableView: UITableView!
    
    private func initPasswordsTableEntries(parent: PasswordEntity?) {
        passwordsTableEntries.removeAll()
        passwordsTableAllEntries.removeAll()
        filteredPasswordsTableEntries.removeAll()
        var passwordEntities = [PasswordEntity]()
        var passwordAllEntities = [PasswordEntity]()
        if Defaults[.isShowFolderOn] {
            passwordEntities = self.passwordStore.fetchPasswordEntityCoreData(parent: parent)
        } else {
            passwordEntities = self.passwordStore.fetchPasswordEntityCoreData(withDir: false)
        }
        passwordsTableEntries = passwordEntities.map {
            PasswordsTableEntry(title: $0.name!, isDir: $0.isDir, passwordEntity: $0)
        }
        passwordAllEntities = self.passwordStore.fetchPasswordEntityCoreData(withDir: false)
        passwordsTableAllEntries = passwordAllEntities.map {
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
                        // will trigger reloadTableView() by a notification
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
    }
    
    private func syncPasswords() {
        SVProgressHUD.setDefaultMaskType(.black)
        SVProgressHUD.setDefaultStyle(.light)
        SVProgressHUD.show(withStatus: "Sync Password Store")
        let numberOfLocalCommits = self.passwordStore.numberOfLocalCommits()
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            do {
                try self.passwordStore.pullRepository(transferProgressBlock: {(git_transfer_progress, stop) in
                    DispatchQueue.main.async {
                        SVProgressHUD.showProgress(Float(git_transfer_progress.pointee.received_objects)/Float(git_transfer_progress.pointee.total_objects), status: "Pull Remote Repository")
                    }
                })
                if numberOfLocalCommits > 0 {
                    try self.passwordStore.pushRepository(transferProgressBlock: {(current, total, bytes, stop) in
                        DispatchQueue.main.async {
                            SVProgressHUD.showProgress(Float(current)/Float(total), status: "Push Remote Repository")
                        }
                    })
                }
                DispatchQueue.main.async {
                    self.reloadTableView(parent: nil)
                    Defaults[.gitPasswordAttempts] = 0
                    SVProgressHUD.showSuccess(withStatus: "Done")
                    SVProgressHUD.dismiss(withDelay: 1)
                }
            } catch {
                DispatchQueue.main.async {
                    SVProgressHUD.dismiss()
                    self.syncControl.endRefreshing()
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(800)) {
                        Utils.alert(title: "Error", message: error.localizedDescription, controller: self, completion: nil)
                    }
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if Defaults[.isShowFolderOn] {
            searchController.searchBar.scopeButtonTitles = ["Current", "All"]
        } else {
            searchController.searchBar.scopeButtonTitles = nil
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tabBarController!.delegate = self
        searchController.searchBar.delegate = self
        tableView.delegate = self
        tableView.dataSource = self
        definesPresentationContext = true
        view.addSubview(searchBarView)
        tableView.insertSubview(syncControl, at: 0)
        SVProgressHUD.setDefaultMaskType(.black)
        tableView.register(UINib(nibName: "PasswordWithFolderTableViewCell", bundle: nil), forCellReuseIdentifier: "passwordWithFolderTableViewCell")
        
        // initialize the password table
        reloadTableView(parent: nil)
        
        // reset the data table if some password (maybe another one) has been updated
        NotificationCenter.default.addObserver(self, selector: #selector(actOnReloadTableViewRelatedNotification), name: .passwordStoreUpdated, object: nil)
        // reset the data table if the disaply settings have been changed
        NotificationCenter.default.addObserver(self, selector: #selector(actOnReloadTableViewRelatedNotification), name: .passwordDisplaySettingChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(actOnSearchNotification), name: .passwordSearch, object: nil)
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
        return sections[section].entries.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction(_:)))
        longPressGestureRecognizer.minimumPressDuration = 0.6
        if Defaults[.isShowFolderOn] && searchController.searchBar.selectedScopeButtonIndex == 0{
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
                cell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .body)
                cell.detailTextLabel?.text = "\(entry.passwordEntity?.children?.count ?? 0)"
            }
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "passwordTableViewCell", for: indexPath)
            let entry = getPasswordEntry(by: indexPath)
            if entry.passwordEntity!.synced {
                cell.textLabel?.text = entry.title
            } else {
                cell.textLabel?.text = "↻ \(entry.title)"
            }
            cell.accessoryType = .none
            cell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .footnote)
            cell.detailTextLabel?.text = entry.passwordEntity?.getCategoryText()
            cell.addGestureRecognizer(longPressGestureRecognizer)
            return cell
        }

    }
    
    private func getPasswordEntry(by indexPath: IndexPath) -> PasswordsTableEntry {
        return sections[indexPath.section].entries[indexPath.row]
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
            reloadTableView(parent: entry.passwordEntity, anim: transitionFromRight)
        }
    }
    
    func backAction(_ sender: Any?) {
        guard Defaults[.isShowFolderOn] else { return }
        reloadTableView(parent: parentPasswordEntity?.parent, anim: transitionFromLeft)
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
    
    private func copyToPasteboard(from indexPath: IndexPath) {
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
    
    private func decryptThenCopyPassword(passwordEntity: PasswordEntity, passphrase: String) {
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
    
    private func generateSections(item: [PasswordsTableEntry]) {
        let collation = UILocalizedIndexedCollation.current()
        let sectionTitles = collation.sectionIndexTitles
        var newSections = [(title: String, entries: [PasswordsTableEntry])]()
        
        // initialize all sections
        for i in 0..<sectionTitles.count {
            newSections.append((title: sectionTitles[i], entries: [PasswordsTableEntry]()))
        }
        
        // put entries into sections
        for entry in item {
            let sectionNumber = collation.section(for: entry, collationStringSelector: #selector(getter: PasswordsTableEntry.title))
            newSections[sectionNumber].entries.append(entry)
        }
        
        // sort each list and set sectionTitles
        for i in 0..<sectionTitles.count {
            let entriesToSort = newSections[i].entries
            let sortedEntries = collation.sortedArray(from: entriesToSort, collationStringSelector: #selector(getter: PasswordsTableEntry.title))
            newSections[i].entries = sortedEntries as! [PasswordsTableEntry]
        }
        
        // only keep non-empty sections
        sections = newSections.filter {$0.entries.count > 0}
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
        } else if identifier == "addPasswordSegue" {
            guard self.passwordStore.publicKey != nil, self.passwordStore.storeRepository != nil else {
                Utils.alert(title: "Cannot Add Password", message: "Please make sure PGP Key and Git Server are properly set.", controller: self, completion: nil)
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
        switch scope {
        case "All":
            filteredPasswordsTableEntries = passwordsTableAllEntries.filter { entry in
                return entry.title.lowercased().contains(searchText.lowercased())
            }
            if searchController.isActive && searchController.searchBar.text != "" {
                reloadTableView(data: filteredPasswordsTableEntries)
            } else {
                reloadTableView(data: passwordsTableAllEntries)
            }
        case "Current":
            filteredPasswordsTableEntries = passwordsTableEntries.filter { entry in
                return entry.title.lowercased().contains(searchText.lowercased())
            }
            if searchController.isActive && searchController.searchBar.text != "" {
                reloadTableView(data: filteredPasswordsTableEntries)
            } else {
                reloadTableView(data: passwordsTableEntries)
            }
        default:
            break
        }
        
        
    }
    
    private func reloadTableView(data: [PasswordsTableEntry], anim: CAAnimation? = nil) {
        // set navigation item
        var numberOfLocalCommitsString = ""
        let numberOfLocalCommits = self.passwordStore.numberOfLocalCommits()
        if numberOfLocalCommits > 0 {
            numberOfLocalCommitsString = " (\(numberOfLocalCommits))"
        }
        if parentPasswordEntity != nil {
            navigationItem.title = "\(parentPasswordEntity!.name!)\(numberOfLocalCommitsString)"
            navigationItem.leftBarButtonItem = backUIBarButtonItem
        } else {
            navigationItem.title = "Password Store\(numberOfLocalCommitsString)"
            navigationItem.leftBarButtonItem = nil
        }
        
        // set the password table
        generateSections(item: data)
        if anim != nil {
            self.tableView.layer.add(anim!, forKey: "UITableViewReloadDataAnimationKey")
        }
        tableView.reloadData()
        self.tableView.layer.removeAnimation(forKey: "UITableViewReloadDataAnimationKey")
        
        // set the sync control title
        let atribbutedTitle = "Last Synced: \(Utils.getLastSyncedTimeString())"
        syncControl.attributedTitle = NSAttributedString(string: atribbutedTitle)
    }
    
    private func reloadTableView(parent: PasswordEntity?, anim: CAAnimation? = nil) {
        initPasswordsTableEntries(parent: parent)
        reloadTableView(data: passwordsTableEntries, anim: anim)
    }
    
    func actOnReloadTableViewRelatedNotification() {
        initPasswordsTableEntries(parent: nil)
        DispatchQueue.main.async { [weak weakSelf = self] in
            guard let strongSelf = weakSelf else { return }
            strongSelf.reloadTableView(data: strongSelf.passwordsTableEntries)
        }
    }
    
    func handleRefresh(_ syncControl: UIRefreshControl) {
        syncPasswords()
        syncControl.endRefreshing()
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
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        updateSearchResults(for: searchController)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchController.searchBar.selectedScopeButtonIndex = 0
        updateSearchResults(for: searchController)
    }
}

extension PasswordsViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        var scope = "All"
        if let scopeButtonTitles = searchController.searchBar.scopeButtonTitles {
            scope = scopeButtonTitles[searchController.searchBar.selectedScopeButtonIndex]
        }
        filterContentForSearchText(searchText: searchController.searchBar.text!, scope: scope)
    }
}
