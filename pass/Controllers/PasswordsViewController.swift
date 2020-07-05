//
//  PasswordsViewController.swift
//  pass
//
//  Created by Mingshen Sun on 3/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import passKit
import SVProgressHUD
import UIKit

class PasswordsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITabBarControllerDelegate, UISearchBarDelegate {
    // Arbitrary threshold to decide whether to show folders or not for only a few entries.
    private static let hideSectionHeaderThreshold = 6

    private var passwordsTableEntries: [PasswordTableEntry] = []
    private var passwordsTableAllEntries: [PasswordTableEntry] = []
    private var parentPasswordEntity: PasswordEntity?
    private let passwordStore = PasswordStore.shared
    private let keychain = AppKeychain.shared

    private var tapTabBarTime: TimeInterval = 0
    private var tapNavigationBarGestureRecognizer: UITapGestureRecognizer!

    private var sections = [(title: String, entries: [PasswordTableEntry])]()

    private enum PasswordLabel {
        case all
        case unsynced
    }

    private var gitCredential: GitCredential {
        switch Defaults.gitAuthenticationMethod {
        case .password:
            return GitCredential(credential: .http(userName: Defaults.gitUsername))
        case .key:
            let privateKey: String = AppKeychain.shared.get(for: SshKey.PRIVATE.getKeychainKey()) ?? ""
            return GitCredential(credential: .ssh(userName: Defaults.gitUsername, privateKey: privateKey))
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
        transition.delegate = self
        return transition
    }()

    private lazy var transitionFromLeft: CATransition = {
        let transition = CATransition()
        transition.type = CATransitionType.push
        transition.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        transition.fillMode = CAMediaTimingFillMode.forwards
        transition.duration = 0.25
        transition.subtype = CATransitionSubtype.fromLeft
        transition.delegate = self
        return transition
    }()

    @IBOutlet var tableView: UITableView!

    private func initPasswordsTableEntries(parent: PasswordEntity?) {
        let passwordAllEntities = passwordStore.fetchPasswordEntityCoreData(withDir: false)
        passwordsTableAllEntries = passwordAllEntities.compactMap {
            PasswordTableEntry($0)
        }

        let passwordEntities = Defaults.isShowFolderOn ?
            passwordStore.fetchPasswordEntityCoreData(parent: parent) :
            passwordAllEntities
        passwordsTableEntries = passwordEntities.compactMap {
            PasswordTableEntry($0)
        }

        parentPasswordEntity = parent
    }

    @IBAction
    private func cancelAddPassword(segue _: UIStoryboardSegue) {}

    @IBAction
    private func saveAddPassword(segue: UIStoryboardSegue) {
        if let controller = segue.source as? AddPasswordTableViewController {
            addPassword(password: controller.password!)
        }
    }

    private func addPassword(password: Password, keyID: String? = nil) {
        SVProgressHUD.setDefaultMaskType(.black)
        SVProgressHUD.setDefaultStyle(.light)
        SVProgressHUD.show(withStatus: "Saving".localize())
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                _ = try self.passwordStore.add(password: password, keyID: keyID)
                DispatchQueue.main.async {
                    // will trigger reloadTableView() by a notification
                    SVProgressHUD.showSuccess(withStatus: "Done".localize())
                    SVProgressHUD.dismiss(withDelay: 1)
                }
            } catch let AppError.PgpPublicKeyNotFound(key) {
                DispatchQueue.main.async {
                    // alert: cancel or select keys
                    SVProgressHUD.dismiss()
                    let alert = UIAlertController(title: "Cannot Encrypt Password", message: AppError.PgpPublicKeyNotFound(keyID: key).localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction.cancelAndPopView(controller: self))
                    let selectKey = UIAlertAction.selectKey(controller: self) { action in
                        self.addPassword(password: password, keyID: action.title)
                    }
                    alert.addAction(selectKey)

                    self.present(alert, animated: true, completion: nil)
                }
                return
            } catch {
                DispatchQueue.main.async {
                    Utils.alert(title: "Error".localize(), message: error.localizedDescription, controller: self, completion: nil)
                }
            }
        }
    }

    private func syncPasswords() {
        guard passwordStore.repositoryExists() else {
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
                try self.passwordStore.pullRepository(credential: self.gitCredential, requestCredentialPassword: self.requestCredentialPassword) { git_transfer_progress, _ in
                    DispatchQueue.main.async {
                        SVProgressHUD.showProgress(Float(git_transfer_progress.pointee.received_objects) / Float(git_transfer_progress.pointee.total_objects), status: "PullingFromRemoteRepository".localize())
                    }
                }
                if self.passwordStore.numberOfLocalCommits > 0 {
                    try self.passwordStore.pushRepository(credential: self.gitCredential, requestCredentialPassword: self.requestCredentialPassword) { current, total, _, _ in
                        DispatchQueue.main.async {
                            SVProgressHUD.showProgress(Float(current) / Float(total), status: "PushingToRemoteRepository".localize())
                        }
                    }
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
            searchController.searchBar.scopeButtonTitles = SearchBarScope.allCases.map(\.localizedName)
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
            tableView.contentInset = UIEdgeInsets(top: 44, left: 0, bottom: 0, right: 0)
            view.addSubview(searchBarView!)
        }
        navigationItem.title = "PasswordStore".localize()
        tapNavigationBarGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapNavigationBar))

        SVProgressHUD.setDefaultMaskType(.black)
        tableView.register(UINib(nibName: "PasswordWithFolderTableViewCell", bundle: nil), forCellReuseIdentifier: "passwordWithFolderTableViewCell")

        // initialize the password table
        reloadTableView(parent: nil)

        // reset the data table if some password (maybe another one) has been updated
        NotificationCenter.default.addObserver(self, selector: #selector(actOnReloadTableViewRelatedNotification), name: .passwordStoreUpdated, object: nil)
        // reset the data table if the disaply settings have been changed
        NotificationCenter.default.addObserver(self, selector: #selector(actOnReloadTableViewRelatedNotification), name: .passwordDisplaySettingChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(actOnSearchNotification), name: .passwordSearch, object: nil)
        // A Siri shortcut can change the state of the app in the background. Hence, reload when opening the app.
        NotificationCenter.default.addObserver(self, selector: #selector(actOnReloadTableViewRelatedNotification), name: UIApplication.willEnterForegroundNotification, object: nil)

        // listen to the swipe back guesture
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(respondToSwipeGesture))
        swipeRight.direction = UISwipeGestureRecognizer.Direction.right
        view.addGestureRecognizer(swipeRight)
    }

    @objc
    func didTapNavigationBar(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: navigationController?.navigationBar)
        let hitView = navigationController?.navigationBar.hitTest(location, with: nil)
        guard !(hitView is UIControl) else {
            return
        }
        guard passwordStore.numberOfLocalCommits != 0 else {
            return
        }

        let ac = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let allAction = UIAlertAction(title: "All Passwords", style: .default) { _ in
            self.reloadTableView(parent: nil, label: .all)
        }
        let unsyncedAction = UIAlertAction(title: "Unsynced Passwords", style: .default) { _ in
            let filteredPasswordsTableEntries = self.passwordsTableEntries.filter { entry in
                !entry.synced
            }
            self.reloadTableView(data: filteredPasswordsTableEntries, label: .unsynced)
        }
        let cancelAction = UIAlertAction.cancel()

        ac.addAction(allAction)
        ac.addAction(unsyncedAction)
        ac.addAction(cancelAction)

        present(ac, animated: true, completion: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController!.delegate = self
        if let path = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: path, animated: false)
        }

        // Add gesture recognizer to the navigation bar when the view is about to appear
        navigationController?.navigationBar.addGestureRecognizer(tapNavigationBarGestureRecognizer)

        // This allows controlls in the navigation bar to continue receiving touches
        tapNavigationBarGestureRecognizer.cancelsTouchesInView = false

        tableView.refreshControl = passwordStore.repositoryExists() ? syncControl : nil
    }

    override func viewWillDisappear(_: Bool) {
        // Remove gesture recognizer from navigation bar when view is about to disappear
        navigationController?.navigationBar.removeGestureRecognizer(tapNavigationBarGestureRecognizer)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        guard #available(iOS 11, *) else {
            searchBarView?.frame = CGRect(x: 0, y: navigationController!.navigationBar.bounds.size.height + UIApplication.shared.statusBarFrame.height, width: UIScreen.main.bounds.width, height: 44)
            searchController.searchBar.sizeToFit()
            return
        }
    }

    func numberOfSections(in _: UITableView) -> Int {
        sections.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].entries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let longPressGestureRecognizer: UILongPressGestureRecognizer = {
            let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction))
            recognizer.minimumPressDuration = 0.6
            return recognizer
        }()
        let entry = getPasswordEntry(by: indexPath)
        let passwordEntity = entry.passwordEntity
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

    private func getPasswordEntry(by indexPath: IndexPath) -> PasswordTableEntry {
        sections[indexPath.section].entries[indexPath.row]
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

    @objc
    func respondToSwipeGesture(gesture: UIGestureRecognizer) {
        if let swipeGesture = gesture as? UISwipeGestureRecognizer {
            // swipe right -> swipe back
            if swipeGesture.direction == .right, parentPasswordEntity != nil {
                backAction(nil)
            }
        }
    }

    @objc
    func backAction(_: Any?) {
        guard Defaults.isShowFolderOn else {
            return
        }
        var anim: CATransition? = transitionFromLeft
        if parentPasswordEntity == nil {
            anim = nil
        }
        reloadTableView(parent: parentPasswordEntity?.parent, anim: anim)
    }

    @objc
    func addPasswordAction(_: Any?) {
        if shouldPerformSegue(withIdentifier: "addPasswordSegue", sender: self) {
            performSegue(withIdentifier: "addPasswordSegue", sender: self)
        }
    }

    @objc
    func longPressAction(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == UIGestureRecognizer.State.began {
            let touchPoint = gesture.location(in: tableView)
            if let indexPath = tableView.indexPathForRow(at: touchPoint) {
                decryptThenCopyPassword(from: indexPath)
            }
        }
    }

    private func hideSectionHeader() -> Bool {
        passwordsTableEntries.count < Self.hideSectionHeaderThreshold || searchController.isActive
    }

    func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        if hideSectionHeader() {
            return nil
        }
        return sections[section].title
    }

    func sectionIndexTitles(for _: UITableView) -> [String]? {
        if hideSectionHeader() {
            return nil
        }
        return sections.map(\.title)
    }

    func tableView(_: UITableView, sectionForSectionIndexTitle _: String, at index: Int) -> Int {
        index
    }

    func tableView(_: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        decryptThenCopyPassword(from: indexPath)
    }

    private func decryptThenCopyPassword(from indexPath: IndexPath) {
        guard PGPAgent.shared.isPrepared else {
            Utils.alert(title: "CannotCopyPassword".localize(), message: "PgpKeyNotSet.".localize(), controller: self)
            return
        }
        let passwordEntity = getPasswordEntry(by: indexPath).passwordEntity
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        SVProgressHUD.dismiss()
        decryptPassword(passwordEntity: passwordEntity)
    }

    private func decryptPassword(passwordEntity: PasswordEntity, keyID: String? = nil) {
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                let requestPGPKeyPassphrase = Utils.createRequestPGPKeyPassphraseHandler(controller: self)
                let decryptedPassword = try self.passwordStore.decrypt(passwordEntity: passwordEntity, keyID: keyID, requestPGPKeyPassphrase: requestPGPKeyPassphrase)

                DispatchQueue.main.async {
                    SecurePasteboard.shared.copy(textToCopy: decryptedPassword.password)
                    SVProgressHUD.setDefaultMaskType(.black)
                    SVProgressHUD.setDefaultStyle(.dark)
                    SVProgressHUD.showSuccess(withStatus: "PasswordCopiedToPasteboard.".localize())
                    SVProgressHUD.dismiss(withDelay: 0.6)
                }
            } catch let AppError.PgpPrivateKeyNotFound(key) {
                DispatchQueue.main.async {
                    // alert: cancel or try again
                    let alert = UIAlertController(title: "CannotShowPassword".localize(), message: AppError.PgpPrivateKeyNotFound(keyID: key).localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction.cancelAndPopView(controller: self))
                    let selectKey = UIAlertAction.selectKey(controller: self) { action in
                        self.decryptPassword(passwordEntity: passwordEntity, keyID: action.title)
                    }
                    alert.addAction(selectKey)

                    self.present(alert, animated: true)
                }
            } catch {
                DispatchQueue.main.async {
                    Utils.alert(title: "CannotCopyPassword".localize(), message: error.localizedDescription, controller: self)
                }
            }
        }
    }

    private func generateSections(item: [PasswordTableEntry]) {
        let collation = UILocalizedIndexedCollation.current()
        let sectionTitles = collation.sectionIndexTitles
        var newSections = [(title: String, entries: [PasswordTableEntry])]()

        // initialize all sections
        for i in 0 ..< sectionTitles.count {
            newSections.append((title: sectionTitles[i], entries: [PasswordTableEntry]()))
        }

        // put entries into sections
        for entry in item {
            let sectionNumber = collation.section(for: entry, collationStringSelector: #selector(getter: PasswordTableEntry.title))
            newSections[sectionNumber].entries.append(entry)
        }

        // sort each list and set sectionTitles
        for i in 0 ..< sectionTitles.count {
            let entriesToSort = newSections[i].entries
            let sortedEntries = collation.sortedArray(from: entriesToSort, collationStringSelector: #selector(getter: PasswordTableEntry.title))
            newSections[i].entries = sortedEntries as! [PasswordTableEntry]
        }

        // only keep non-empty sections
        sections = newSections.filter { !$0.entries.isEmpty }
    }

    @objc
    func actOnSearchNotification() {
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
            guard PGPAgent.shared.isPrepared && passwordStore.storeRepository != nil else {
                Utils.alert(title: "CannotAddPassword".localize(), message: "MakeSurePgpAndGitProperlySet.".localize(), controller: self, completion: nil)
                return false
            }
        }
        return true
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showPasswordDetail" {
            if let viewController = segue.destination as? PasswordDetailTableViewController {
                let selectedIndexPath = tableView.indexPath(for: sender as! UITableViewCell)!
                let passwordEntity = getPasswordEntry(by: selectedIndexPath).passwordEntity
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
        var entries: [PasswordTableEntry] = scope == .all ? passwordsTableAllEntries : passwordsTableEntries
        if searchController.isActive, let searchBarText = searchController.searchBar.text, !searchBarText.isEmpty {
            entries = entries.filter { $0.match(searchText) }
        }
        reloadTableView(data: entries)
    }

    private func reloadTableView(data: [PasswordTableEntry], label: PasswordLabel = .all, anim: CAAnimation? = nil) {
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
            navigationController?.navigationBar.removeGestureRecognizer(tapNavigationBarGestureRecognizer)
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
            navigationController?.navigationBar.addGestureRecognizer(tapNavigationBarGestureRecognizer)
        }
        navigationItem.rightBarButtonItem = addPasswordUIBarButtonItem

        // set the password table
        generateSections(item: data)
        if anim != nil {
            tableView.layer.add(anim!, forKey: "UITableViewReloadDataAnimationKey")
        }
        tableView.reloadData()
        tableView.layer.removeAnimation(forKey: "UITableViewReloadDataAnimationKey")

        // set the sync control title
        let atribbutedTitle = "LastSynced".localize() + ": \(lastSyncedTimeString())"
        syncControl.attributedTitle = NSAttributedString(string: atribbutedTitle)
    }

    private func lastSyncedTimeString() -> String {
        guard let date = passwordStore.lastSyncedTime else {
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

    @objc
    func actOnReloadTableViewRelatedNotification() {
        DispatchQueue.main.async { [weak weakSelf = self] in
            guard let strongSelf = weakSelf else {
                return
            }
            // Reset selectedScopeButtonIndex to make sure the correct reloadTableView
            strongSelf.searchController.searchBar.selectedScopeButtonIndex = 0
            strongSelf.initPasswordsTableEntries(parent: nil)
            strongSelf.reloadTableView(data: strongSelf.passwordsTableEntries)
        }
    }

    @objc
    func handleRefresh(_: UIRefreshControl) {
        syncPasswords()
    }

    func tabBarController(_: UITabBarController, didSelect viewController: UIViewController) {
        if viewController == navigationController {
            let currentTime = Date().timeIntervalSince1970
            let duration = currentTime - tapTabBarTime
            tapTabBarTime = currentTime
            if duration < 0.35 {
                let topIndexPath = IndexPath(row: 0, section: 0)
                if tableView.numberOfSections > 0 {
                    tableView.scrollToRow(at: topIndexPath, at: .bottom, animated: true)
                }
                tapTabBarTime = 0
                return
            }
            backAction(self)
        }
    }

    func searchBar(_: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        // update the default search scope
        Defaults.searchDefault = SearchBarScope(rawValue: selectedScope)
        updateSearchResults(for: searchController)
    }

    func searchBarShouldBeginEditing(_: UISearchBar) -> Bool {
        // set the default search scope to "all"
        if Defaults.isShowFolderOn, Defaults.searchDefault == .all {
            searchController.searchBar.selectedScopeButtonIndex = SearchBarScope.all.rawValue
        } else {
            searchController.searchBar.selectedScopeButtonIndex = SearchBarScope.current.rawValue
        }
        return true
    }

    func searchBarShouldEndEditing(_: UISearchBar) -> Bool {
        // set the default search scope to "current"
        searchController.searchBar.selectedScopeButtonIndex = SearchBarScope.current.rawValue
        updateSearchResults(for: searchController)
        return true
    }

    private func requestCredentialPassword(credential: GitCredential.Credential, lastPassword: String?) -> String? {
        requestGitCredentialPassword(credential: credential, lastPassword: lastPassword, controller: self)
    }
}

extension PasswordsViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let scope = SearchBarScope(rawValue: searchController.searchBar.selectedScopeButtonIndex) ?? .all
        filterContentForSearchText(searchText: searchController.searchBar.text!, scope: scope)
    }
}

extension PasswordsViewController: CAAnimationDelegate {
    func animationDidStart(_: CAAnimation) {
        view.window?.backgroundColor = Colors.systemBackground
        view.layer.backgroundColor = Colors.systemBackground.cgColor
    }
}
