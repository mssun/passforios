//
//  PasswordsViewController.swift
//  pass
//
//  Created by Mingshen Sun on 3/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import SVProgressHUD
import passKit

fileprivate class PasswordsTableEntry : NSObject {
    @objc var title: String
    var isDir: Bool
    var passwordEntity: PasswordEntity?
    init(title: String, isDir: Bool, passwordEntity: PasswordEntity?) {
        self.title = title
        self.isDir = isDir
        self.passwordEntity = passwordEntity
    }
}

fileprivate let hideSectionHeaderTreshold = 6    // hide section header if passwords count is less than the threshold

class PasswordsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITabBarControllerDelegate, UISearchBarDelegate {
    private var passwordsTableEntries: [PasswordsTableEntry] = []
    private var passwordsTableAllEntries: [PasswordsTableEntry] = []
    private var filteredPasswordsTableEntries: [PasswordsTableEntry] = []
    private var parentPasswordEntity: PasswordEntity? = nil
    private let passwordStore = PasswordStore.shared
    private let keychain = AppKeychain.shared

    private var tapTabBarTime: TimeInterval = 0
    private var tapNavigationBarGestureRecognizer: UITapGestureRecognizer!

    private var sections = [(title: String, entries: [PasswordsTableEntry])]()

    private var searchActive : Bool = false
    private enum PasswordLabel {
        case all
        case unsynced
    }

    private var gitCredential: GitCredential {
        get {
            switch Defaults.gitAuthenticationMethod {
            case .password:
                return GitCredential(credential: .http(userName: Defaults.gitUsername))
            case .key:
                let privateKey: String = AppKeychain.shared.get(for: SshKey.PRIVATE.getKeychainKey()) ?? ""
                return GitCredential(credential: .ssh(userName: Defaults.gitUsername, privateKey: privateKey))
            }
        }
    }

    private lazy var searchController: UISearchController = {
        let uiSearchController = UISearchController(searchResultsController: nil)
        uiSearchController.searchResultsUpdater = self
        uiSearchController.dimsBackgroundDuringPresentation = false
        uiSearchController.searchBar.isTranslucent = false
        uiSearchController.searchBar.sizeToFit()
        return uiSearchController
    }()
    private lazy var syncControl: UIRefreshControl = {
        let syncControl = UIRefreshControl()
        syncControl.addTarget(self, action: #selector(handleRefresh(_:)), for: UIControl.Event.valueChanged)
        return syncControl
    }()
    private lazy var searchBarView: UIView? = {
        guard #available(iOS 11, *) else {
            let uiView = UIView(frame: CGRect(x: 0, y: 64, width: self.view.bounds.width, height: 44))
            uiView.addSubview(self.searchController.searchBar)
            return uiView
        }
        return nil
    }()
    private lazy var backUIBarButtonItem: UIBarButtonItem = {
        let backUIButton = UIButton(type: .system)
        if #available(iOS 13.0, *) {
            let leftImage = UIImage(systemName: "chevron.left", withConfiguration: UIImage.SymbolConfiguration(weight: .bold))
            backUIButton.setImage(leftImage, for: .normal)
            backUIButton.setTitle("Back".localize(), for: .normal)
            let padding = CGFloat(integerLiteral: 3)
            backUIButton.contentEdgeInsets.right += padding
            backUIButton.titleEdgeInsets.left = padding
            backUIButton.titleEdgeInsets.right = -padding
        } else {
            backUIButton.setTitle("Back".localize(), for: .normal)
        }
        backUIButton.addTarget(self, action: #selector(self.backAction(_:)), for: .touchDown)
        let backUIBarButtonItem = UIBarButtonItem(customView: backUIButton)
        return backUIBarButtonItem
    }()

    private lazy var addPasswordUIBarButtonItem: UIBarButtonItem = {
        var addPasswordUIBarButtonItem = UIBarButtonItem()
        if #available(iOS 13.0, *) {
            let addPasswordButton = UIButton(type: .system)
            let plusImage = UIImage(systemName: "plus.circle", withConfiguration: UIImage.SymbolConfiguration(weight: .regular))
            addPasswordButton.setImage(plusImage, for: .normal)
            addPasswordButton.addTarget(self, action: #selector(self.addPasswordAction(_:)), for: .touchDown)
            addPasswordUIBarButtonItem.customView = addPasswordButton
        } else {
            addPasswordUIBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(self.addPasswordAction(_:)))
        }
        return addPasswordUIBarButtonItem
    }()

    private lazy var transitionFromRight: CATransition = {
        let transition = CATransition()
        transition.type = CATransitionType.push
        transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        transition.fillMode = CAMediaTimingFillMode.forwards
        transition.duration = 0.25
        transition.subtype = CATransitionSubtype.fromRight
        return transition
    }()

    private lazy var transitionFromLeft: CATransition = {
        let transition = CATransition()
        transition.type = CATransitionType.push
        transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        transition.fillMode = CAMediaTimingFillMode.forwards
        transition.duration = 0.25
        transition.subtype = CATransitionSubtype.fromLeft
        return transition
    }()

    @IBOutlet weak var tableView: UITableView!

    private func initPasswordsTableEntries(parent: PasswordEntity?) {
        passwordsTableEntries.removeAll()
        passwordsTableAllEntries.removeAll()
        filteredPasswordsTableEntries.removeAll()
        var passwordEntities = [PasswordEntity]()
        var passwordAllEntities = [PasswordEntity]()
        if Defaults.isShowFolderOn {
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
            SVProgressHUD.show(withStatus: "Saving".localize())
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let _ = try self.passwordStore.add(password: controller.password!)
                    DispatchQueue.main.async {
                        // will trigger reloadTableView() by a notification
                        SVProgressHUD.showSuccess(withStatus: "Done".localize())
                        SVProgressHUD.dismiss(withDelay: 1)
                    }
                } catch {
                    DispatchQueue.main.async {
                        Utils.alert(title: "Error".localize(), message: error.localizedDescription, controller: self, completion: nil)
                    }
                }
            }
        }
    }

    private func syncPasswords() {
        guard passwordStore.repositoryExisted() else {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(800)) {
                Utils.alert(title: "Error".localize(), message: "NoPasswordStore.".localize(), controller: self, completion: nil)
            }
            return
        }
        SVProgressHUD.setDefaultMaskType(.black)
        SVProgressHUD.setDefaultStyle(.light)
        SVProgressHUD.show(withStatus: "SyncingPasswordStore".localize())


        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            do {
                try self.passwordStore.pullRepository(credential: self.gitCredential, requestCredentialPassword: self.requestCredentialPassword, progressBlock: {(git_transfer_progress, stop) in
                    DispatchQueue.main.async {
                        SVProgressHUD.showProgress(Float(git_transfer_progress.pointee.received_objects)/Float(git_transfer_progress.pointee.total_objects), status: "PullingFromRemoteRepository".localize())
                    }
                })
                if self.passwordStore.numberOfLocalCommits > 0 {
                    try self.passwordStore.pushRepository(credential: self.gitCredential, requestCredentialPassword: self.requestCredentialPassword, transferProgressBlock: {(current, total, bytes, stop) in
                        DispatchQueue.main.async {
                            SVProgressHUD.showProgress(Float(current)/Float(total), status: "PushingToRemoteRepository".localize())
                        }
                    })
                }
                DispatchQueue.main.async {
                    self.reloadTableView(parent: nil)
                    SVProgressHUD.showSuccess(withStatus: "Done".localize())
                    SVProgressHUD.dismiss(withDelay: 1)
                    self.syncControl.endRefreshing()
                }
            } catch {
                DispatchQueue.main.async {
                    SVProgressHUD.dismiss()
                    self.syncControl.endRefreshing()
                    let error = error as NSError
                    var message = error.localizedDescription
                    if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                        message = message | "UnderlyingError".localize(underlyingError.localizedDescription)
                        if underlyingError.localizedDescription.contains("WrongPassphrase".localize()) {
                            message = message | "RecoverySuggestion.".localize()
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(800)) {
                        Utils.alert(title: "Error".localize(), message: message, controller: self, completion: nil)
                    }
                }
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if Defaults.isShowFolderOn {
            searchController.searchBar.scopeButtonTitles = SearchBarScope.allCases.map { $0.localizedName }
        } else {
            searchController.searchBar.scopeButtonTitles = nil
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        searchController.searchBar.delegate = self
        tableView.delegate = self
        tableView.dataSource = self
        definesPresentationContext = true
        if #available(iOS 11.0, *) {
            navigationItem.searchController = searchController
            navigationController?.navigationBar.prefersLargeTitles = true
            navigationItem.largeTitleDisplayMode = .automatic
            navigationItem.hidesSearchBarWhenScrolling = false
        } else {
            // Fallback on earlier versions
            tableView.contentInset = UIEdgeInsets.init(top: 44, left: 0, bottom: 0, right: 0)
            view.addSubview(searchBarView!)
        }
        navigationItem.title = "PasswordStore".localize()
        tapNavigationBarGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapNavigationBar))

        tableView.refreshControl = syncControl
        SVProgressHUD.setDefaultMaskType(.black)
        tableView.register(UINib(nibName: "PasswordWithFolderTableViewCell", bundle: nil), forCellReuseIdentifier: "passwordWithFolderTableViewCell")

        // initialize the password table
        reloadTableView(parent: nil)

        // reset the data table if some password (maybe another one) has been updated
        NotificationCenter.default.addObserver(self, selector: #selector(actOnReloadTableViewRelatedNotification), name: .passwordStoreUpdated, object: nil)
        // reset the data table if the disaply settings have been changed
        NotificationCenter.default.addObserver(self, selector: #selector(actOnReloadTableViewRelatedNotification), name: .passwordDisplaySettingChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(actOnSearchNotification), name: .passwordSearch, object: nil)

        // listen to the swipe back guesture
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(self.respondToSwipeGesture))
        swipeRight.direction = UISwipeGestureRecognizer.Direction.right
        self.view.addGestureRecognizer(swipeRight)
    }

    @objc func didTapNavigationBar(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: self.navigationController?.navigationBar)
        let hitView = self.navigationController?.navigationBar.hitTest(location, with: nil)
        guard !(hitView is UIControl) else { return }
        guard (passwordStore.numberOfLocalCommits != 0) else { return }

        let ac = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let allAction = UIAlertAction(title: "All Passwords", style: .default) { _ in
            self.reloadTableView(parent: nil, label: .all)
        }
        let unsyncedAction = UIAlertAction(title: "Unsynced Passwords", style: .default) { _ in
            self.filteredPasswordsTableEntries = self.passwordsTableEntries.filter { entry in
                return !entry.passwordEntity!.synced
            }
            self.reloadTableView(data: self.filteredPasswordsTableEntries, label: .unsynced)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

        ac.addAction(allAction)
        ac.addAction(unsyncedAction)
        ac.addAction(cancelAction)

        self.present(ac, animated: true, completion: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController!.delegate = self
        if let path = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: path, animated: false)
        }

        // Add gesture recognizer to the navigation bar when the view is about to appear
        self.navigationController?.navigationBar.addGestureRecognizer(tapNavigationBarGestureRecognizer)

        // This allows controlls in the navigation bar to continue receiving touches
        tapNavigationBarGestureRecognizer.cancelsTouchesInView = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        // Remove gesture recognizer from navigation bar when view is about to disappear
        self.navigationController?.navigationBar.removeGestureRecognizer(tapNavigationBarGestureRecognizer)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        guard #available(iOS 11, *) else {
            searchBarView?.frame = CGRect(x: 0, y: navigationController!.navigationBar.bounds.size.height + UIApplication.shared.statusBarFrame.height, width: UIScreen.main.bounds.width, height: 44)
            searchController.searchBar.sizeToFit()
            return
        }
    }

     func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].entries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let longPressGestureRecognizer: UILongPressGestureRecognizer = {
            let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction))
            recognizer.minimumPressDuration = 0.6
            return recognizer
        }()
        let entry = getPasswordEntry(by: indexPath)
        let passwordEntity = entry.passwordEntity!
        let cell = tableView.dequeueReusableCell(withIdentifier: "passwordTableViewCell", for: indexPath)

        cell.textLabel?.text = passwordEntity.synced ? entry.title : "↻ \(entry.title)"
        cell.textLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        cell.textLabel?.adjustsFontForContentSizeCategory = true
        cell.accessoryType = .none
        cell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .footnote)
        cell.detailTextLabel?.adjustsFontForContentSizeCategory = true
        cell.addGestureRecognizer(longPressGestureRecognizer)

        if entry.isDir {
            cell.accessoryType = .disclosureIndicator
            cell.textLabel?.font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .medium)
            cell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .body)
            cell.detailTextLabel?.text = "\(passwordEntity.children?.count ?? 0)"
            cell.removeGestureRecognizer(longPressGestureRecognizer)
        } else {
            cell.detailTextLabel?.text = passwordEntity.getCategoryText()
        }

        return cell
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

    @objc func respondToSwipeGesture(gesture: UIGestureRecognizer) {
        if let swipeGesture = gesture as? UISwipeGestureRecognizer {
            // swipe right -> swipe back
            if swipeGesture.direction == .right && parentPasswordEntity != nil {
                self.backAction(nil)
            }
        }
    }

    @objc func backAction(_ sender: Any?) {
        guard Defaults.isShowFolderOn else { return }
        var anim: CATransition? = transitionFromLeft
        if parentPasswordEntity == nil {
            anim = nil
        }
        reloadTableView(parent: parentPasswordEntity?.parent, anim: anim)
    }

    @objc func addPasswordAction(_ sender: Any?) {
        if shouldPerformSegue(withIdentifier: "addPasswordSegue", sender: self) {
            performSegue(withIdentifier: "addPasswordSegue", sender: self)
        }
    }

    @objc func longPressAction(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == UIGestureRecognizer.State.began {
            let touchPoint = gesture.location(in: tableView)
            if let indexPath = tableView.indexPathForRow(at: touchPoint) {
                decryptThenCopyPassword(from: indexPath)
            }
        }
    }

    private func hideSectionHeader() -> Bool {
        if passwordsTableEntries.count < hideSectionHeaderTreshold || self.searchController.isActive {
            return true
        }
        return false
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if hideSectionHeader() {
            return nil
        }
        return sections[section].title
    }

    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        if hideSectionHeader() {
            return nil
        }
        return sections.map { $0.title }
    }

    func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        return index
    }

    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        decryptThenCopyPassword(from: indexPath)
    }

    private func requestPGPKeyPassphrase() -> String {
        let sem = DispatchSemaphore(value: 0)
        var passphrase = ""
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Passphrase".localize(), message: "FillInPgpPassphrase.".localize(), preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "Ok".localize(), style: UIAlertAction.Style.default, handler: {_ in
                passphrase = alert.textFields!.first!.text!
                sem.signal()
            }))
            alert.addTextField(configurationHandler: {(textField: UITextField!) in
                textField.text = self.keychain.get(for: Globals.pgpKeyPassphrase) ?? ""
                textField.isSecureTextEntry = true
            })
            self.present(alert, animated: true, completion: nil)
        }
        let _ = sem.wait(timeout: DispatchTime.distantFuture)
        if Defaults.isRememberPGPPassphraseOn {
            self.keychain.add(string: passphrase, for: Globals.pgpKeyPassphrase)
        }
        return passphrase
    }

    private func decryptThenCopyPassword(from indexPath: IndexPath) {
        guard PGPAgent.shared.isPrepared else {
            Utils.alert(title: "CannotCopyPassword".localize(), message: "PgpKeyNotSet.".localize(), controller: self, completion: nil)
            return
        }
        let passwordEntity = getPasswordEntry(by: indexPath).passwordEntity!
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        SVProgressHUD.dismiss()
        DispatchQueue.global(qos: .userInteractive).async {
            var decryptedPassword: Password?
            do {
                decryptedPassword = try self.passwordStore.decrypt(passwordEntity: passwordEntity, requestPGPKeyPassphrase: self.requestPGPKeyPassphrase)
                DispatchQueue.main.async {
                    SecurePasteboard.shared.copy(textToCopy: decryptedPassword?.password)
                    SVProgressHUD.setDefaultMaskType(.black)
                    SVProgressHUD.setDefaultStyle(.dark)
                    SVProgressHUD.showSuccess(withStatus: "PasswordCopiedToPasteboard.".localize())
                    SVProgressHUD.dismiss(withDelay: 0.6)
                }
            } catch {
                DispatchQueue.main.async {
                    Utils.alert(title: "CannotCopyPassword".localize(), message: error.localizedDescription, controller: self, completion: nil)
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

    @objc func actOnSearchNotification() {
        searchController.searchBar.becomeFirstResponder()
    }


    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "showPasswordDetail" {
            guard PGPAgent.shared.isPrepared else {
                Utils.alert(title: "CannotShowPassword".localize(), message: "PgpKeyNotSet.".localize(), controller: self, completion: nil)
                if let s = sender as? UITableViewCell {
                    let selectedIndexPath = tableView.indexPath(for: s)!
                    tableView.deselectRow(at: selectedIndexPath, animated: true)
                }
                return false
            }
        } else if identifier == "addPasswordSegue" {
            guard PGPAgent.shared.isPrepared && self.passwordStore.storeRepository != nil else {
                Utils.alert(title: "CannotAddPassword".localize(), message: "MakeSurePgpAndGitProperlySet.".localize(), controller: self, completion: nil)
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
        } else if segue.identifier == "addPasswordSegue" {
            if let navController = segue.destination as? UINavigationController {
                if let viewController = navController.topViewController as? AddPasswordTableViewController {
                    if let path = parentPasswordEntity?.getPath() {
                        viewController.defaultDirPrefix = "\(path)/"
                    }
                }
            }
        }
    }

    func filterContentForSearchText(searchText: String, scope: SearchBarScope = .all) {
        switch scope {
        case .all:
            filteredPasswordsTableEntries = passwordsTableAllEntries.filter { entry in
                let name = entry.passwordEntity?.nameWithCategory ?? entry.title
                return name.localizedCaseInsensitiveContains(searchText)
            }
            if searchController.isActive && searchController.searchBar.text != "" {
                reloadTableView(data: filteredPasswordsTableEntries)
            } else {
                reloadTableView(data: passwordsTableAllEntries)
            }
        case .current:
            filteredPasswordsTableEntries = passwordsTableEntries.filter { entry in
                return entry.title.lowercased().contains(searchText.lowercased())
            }
            if searchController.isActive && searchController.searchBar.text != "" {
                reloadTableView(data: filteredPasswordsTableEntries)
            } else {
                reloadTableView(data: passwordsTableEntries)
            }
        }


    }

    private func reloadTableView(data: [PasswordsTableEntry], label: PasswordLabel = .all, anim: CAAnimation? = nil) {
        // set navigation item
        if passwordStore.numberOfLocalCommits != 0 {
            navigationController?.tabBarItem.badgeValue = "\(passwordStore.numberOfLocalCommits)"
        } else {
            navigationController?.tabBarItem.badgeValue = nil
        }
        if parentPasswordEntity != nil {
            navigationItem.leftBarButtonItem = backUIBarButtonItem
            navigationItem.title = parentPasswordEntity?.getName()
            if #available(iOS 11, *) {
                navigationController?.navigationBar.prefersLargeTitles = false
            }
            self.navigationController?.navigationBar.removeGestureRecognizer(tapNavigationBarGestureRecognizer)
        } else {
            navigationItem.leftBarButtonItem = nil
            switch label {
            case .all:
                navigationItem.title = "PasswordStore".localize()
            case .unsynced:
                navigationItem.title = "Unsynced"
            }
            if #available(iOS 11, *) {
                navigationController?.navigationBar.prefersLargeTitles = true
            }
            self.navigationController?.navigationBar.addGestureRecognizer(tapNavigationBarGestureRecognizer)
        }
        navigationItem.rightBarButtonItem = addPasswordUIBarButtonItem

        // set the password table
        generateSections(item: data)
        if anim != nil {
            self.tableView.layer.add(anim!, forKey: "UITableViewReloadDataAnimationKey")
        }
        tableView.reloadData()
        self.tableView.layer.removeAnimation(forKey: "UITableViewReloadDataAnimationKey")

        // set the sync control title
        let atribbutedTitle = "LastSynced".localize() + ": \(lastSyncedTimeString())"
        syncControl.attributedTitle = NSAttributedString(string: atribbutedTitle)
    }

    private func lastSyncedTimeString() -> String {
        guard let date = self.passwordStore.lastSyncedTime else {
            return "SyncAgain?".localize()
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func reloadTableView(parent: PasswordEntity?, label: PasswordLabel = .all, anim: CAAnimation? = nil) {
        initPasswordsTableEntries(parent: parent)
        reloadTableView(data: passwordsTableEntries, label: label, anim: anim)
    }

    @objc func actOnReloadTableViewRelatedNotification() {
        // Reset selectedScopeButtonIndex to make sure the correct reloadTableView
        searchController.searchBar.selectedScopeButtonIndex = 0
        DispatchQueue.main.async { [weak weakSelf = self] in
            guard let strongSelf = weakSelf else { return }
            strongSelf.initPasswordsTableEntries(parent: nil)
            strongSelf.reloadTableView(data: strongSelf.passwordsTableEntries)
        }
    }

    @objc func handleRefresh(_ syncControl: UIRefreshControl) {
        syncPasswords()
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        if viewController == self.navigationController {
            let currentTime = Date().timeIntervalSince1970
            let duration = currentTime - self.tapTabBarTime
            self.tapTabBarTime = currentTime
            if duration < 0.35 {
                let topIndexPath = IndexPath(row: 0, section: 0)
                    if tableView.numberOfSections > 0 {
                        tableView.scrollToRow(at: topIndexPath, at: .bottom, animated: true)
                    }
                self.tapTabBarTime = 0
                return
            }
            backAction(self)
        }
    }

    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        // update the default search scope
        Defaults.searchDefault = SearchBarScope(rawValue: selectedScope)
        updateSearchResults(for: searchController)
    }

    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        // set the default search scope to "all"
        if Defaults.isShowFolderOn && Defaults.searchDefault == .all {
            searchController.searchBar.selectedScopeButtonIndex = SearchBarScope.all.rawValue
        } else {
            searchController.searchBar.selectedScopeButtonIndex = SearchBarScope.current.rawValue
        }
        return true
    }

    func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
        // set the default search scope to "current"
        searchController.searchBar.selectedScopeButtonIndex = SearchBarScope.current.rawValue
        updateSearchResults(for: searchController)
        return true
    }

    private func requestCredentialPassword(credential: GitCredential.Credential, lastPassword: String?) -> String? {
        return requestGitCredentialPassword(credential: credential, lastPassword: lastPassword, controller: self)
    }

}

extension PasswordsViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let scope = SearchBarScope(rawValue: searchController.searchBar.selectedScopeButtonIndex) ?? .all
        filterContentForSearchText(searchText: searchController.searchBar.text!, scope: scope)
    }
}
