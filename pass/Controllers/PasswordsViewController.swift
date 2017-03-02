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

class PasswordsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private var passwordsTableEntries: [PasswordsTableEntry] = []
    private var filteredPasswordsTableEntries: [PasswordsTableEntry] = []
    private var parentPasswordEntity: PasswordEntity? = nil

    private func initPasswordsTableEntries() {
        passwordsTableEntries.removeAll()
        filteredPasswordsTableEntries.removeAll()
        var passwordEntities = [PasswordEntity]()
        if Defaults[.isShowFolderOn] {
            passwordEntities = PasswordStore.shared.fetchPasswordEntityCoreData(parent: parentPasswordEntity)
        } else {
            passwordEntities = PasswordStore.shared.fetchPasswordEntityCoreData(withDir: false)

        }
        passwordsTableEntries = passwordEntities.map {
            PasswordsTableEntry(title: $0.name!, isDir: $0.isDir, passwordEntity: $0)
        }
    }
    
    var sections : [(index: Int, length :Int, title: String)] = Array()
    var searchActive : Bool = false
    let searchController = UISearchController(searchResultsController: nil)
    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(PasswordsViewController.handleRefresh(_:)), for: UIControlEvents.valueChanged)
        return refreshControl
    }()
    let searchBarView = UIView(frame: CGRect(x: 0, y: 64, width: UIScreen.main.bounds.width, height: 44))
    lazy var backUIBarButtonItem: UIBarButtonItem = {
        let backUIBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(self.backAction(_:)))
        return backUIBarButtonItem
    }()

    @IBOutlet weak var tableView: UITableView!
    
    @IBAction func cancelAddPassword(segue: UIStoryboardSegue) {
        
    }
    @IBAction func saveAddPassword(segue: UIStoryboardSegue) {
        if let controller = segue.source as? AddPasswordTableViewController {
            SVProgressHUD.setDefaultMaskType(.black)
            SVProgressHUD.setDefaultStyle(.light)
            SVProgressHUD.show(withStatus: "Saving")
            DispatchQueue.global(qos: .userInitiated).async {
                PasswordStore.shared.add(password: controller.password!, progressBlock: { progress in
                    DispatchQueue.main.async {
                        SVProgressHUD.showProgress(progress, status: "Encrypting")
                    }
                })
                DispatchQueue.main.async {
                    SVProgressHUD.showSuccess(withStatus: "Done")
                    SVProgressHUD.dismiss(withDelay: 1)
                    NotificationCenter.default.post(Notification(name: Notification.Name("passwordUpdated")))
                }
            }
        }
    }
    
    func syncPasswords() {
        SVProgressHUD.setDefaultMaskType(.black)
        SVProgressHUD.setDefaultStyle(.light)
        SVProgressHUD.show(withStatus: "Sync Password Store")
        let numberOfUnsyncedPasswords = PasswordStore.shared.getNumberOfUnsyncedPasswords()
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            do {
                try PasswordStore.shared.pullRepository(transferProgressBlock: {(git_transfer_progress, stop) in
                    DispatchQueue.main.async {
                        SVProgressHUD.showProgress(Float(git_transfer_progress.pointee.received_objects)/Float(git_transfer_progress.pointee.total_objects), status: "Pull Remote Repository")
                    }
                })
                if numberOfUnsyncedPasswords > 0 {
                    try PasswordStore.shared.pushRepository(transferProgressBlock: {(current, total, bytes, stop) in
                        DispatchQueue.main.async {
                            SVProgressHUD.showProgress(Float(current)/Float(total), status: "Push Remote Repository")
                        }
                    })
                }
                DispatchQueue.main.async {
                    PasswordStore.shared.updatePasswordEntityCoreData()
                    self.parentPasswordEntity = nil
                    self.initPasswordsTableEntries()
                    self.reloadTableView(data: self.passwordsTableEntries)
                    PasswordStore.shared.setAllSynced()
                    self.setNavigationItemTitle()
                    Defaults[.lastUpdatedTime] = Date()
                    Defaults[.gitRepositoryPasswordAttempts] = 0
                    SVProgressHUD.showSuccess(withStatus: "Done")
                    SVProgressHUD.dismiss(withDelay: 1)
                }
            } catch {
                DispatchQueue.main.async {
                    SVProgressHUD.showError(withStatus: error.localizedDescription)
                    SVProgressHUD.dismiss(withDelay: 1)
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
        initPasswordsTableEntries()
        addNotificationObservers()

        generateSections(item: passwordsTableEntries)
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
        let entry = getPasswordEntry(by: indexPath)
        if !entry.isDir {
            if entry.passwordEntity!.synced {
                cell.textLabel?.text = entry.title
            } else {
                cell.textLabel?.text = "↻ \(entry.title)"
            }
            
            let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction(_:)))
            longPressGestureRecognizer.minimumPressDuration = 0.6
            cell.addGestureRecognizer(longPressGestureRecognizer)
        } else {
            cell.textLabel?.text = "\(entry.title)/"
        }
        return cell
    }
    
    private func getPasswordEntry(by indexPath: IndexPath) -> PasswordsTableEntry{
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
            performSegue(withIdentifier: "showPasswordDetail", sender: tableView.cellForRow(at: indexPath))
        } else {
            tableView.deselectRow(at: indexPath, animated: true)
            parentPasswordEntity = entry.passwordEntity
            initPasswordsTableEntries()
            reloadTableView(data: passwordsTableEntries)
        }
    }
    
    func backAction(_ sender: Any?) {
        parentPasswordEntity = parentPasswordEntity?.parent
        initPasswordsTableEntries()
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
        if Defaults[.pgpKeyID]  == nil {
            Utils.alert(title: "Cannot Copy Password", message: "PGP Key is not set. Please set your PGP Key first.", controller: self, completion: nil)
            return
        }
        let index = sections[indexPath.section].index + indexPath.row
        let password: PasswordEntity
        if searchController.isActive && searchController.searchBar.text != "" {
            password = passwordsTableEntries[index].passwordEntity!
        } else {
            password = filteredPasswordsTableEntries[index].passwordEntity!
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        var passphrase = ""
        if Defaults[.isRememberPassphraseOn] && PasswordStore.shared.pgpKeyPassphrase != nil  {
            passphrase = PasswordStore.shared.pgpKeyPassphrase!
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
                    SVProgressHUD.showSuccess(withStatus: "Password Copied")
                    SVProgressHUD.dismiss(withDelay: 0.6)
                }
            } catch {
                print(error)
                DispatchQueue.main.async {
                    SVProgressHUD.showError(withStatus: error.localizedDescription)
                    SVProgressHUD.dismiss(withDelay: 1)
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
        initPasswordsTableEntries()
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
        let numberOfUnsynced = PasswordStore.shared.getNumberOfUnsyncedPasswords()
        if numberOfUnsynced == 0 {
            navigationItem.title = "\(title)"
        } else {
            navigationItem.title = "\(title) (\(numberOfUnsynced))"
        }
    }
    
    func actOnPasswordStoreErasedNotification() {
        initPasswordsTableEntries()
        reloadTableView(data: passwordsTableEntries)
        setNavigationItemTitle()
    }
    
    func actOnSearchNotification() {
        searchController.searchBar.becomeFirstResponder()
    }

    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "showPasswordDetail" {
            if Defaults[.pgpKeyID]  == nil {
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
}

extension PasswordsViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        filterContentForSearchText(searchText: searchController.searchBar.text!)
    }
}
