//
//  PasswordNavigationViewController.swift
//  pass
//
//  Created by Mingshen Sun on 17/1/2021.
//  Copyright © 2021 Bob Sun. All rights reserved.
//

import passKit
import SVProgressHUD
import UIKit
import UserNotifications

extension UIStoryboard {
    static var passwordNavigationViewController: PasswordNavigationViewController {
        UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "passwordNavigation") as! PasswordNavigationViewController
    }
}

class PasswordNavigationViewController: UIViewController {
    @IBOutlet var tableView: UITableView!

    var dataSource: PasswordNavigationDataSource?
    var parentPasswordEntity: PasswordEntity? {
        didSet {
            parentPath = parentPasswordEntity?.path
        }
    }

    // preserve parent path so it can be reloaded even if the parentPasswordEntity is deleted during the update process
    private var parentPath: String?

    var viewingUnsyncedPasswords = false
    var tapTabBarTime: TimeInterval = 0
    var searchText: String?

    lazy var passwordManager = PasswordManager(viewController: self)

    lazy var searchController: UISearchController = {
        let uiSearchController = UISearchController(searchResultsController: nil)
        uiSearchController.searchBar.isTranslucent = true
        uiSearchController.obscuresBackgroundDuringPresentation = false
        uiSearchController.searchBar.sizeToFit()
        uiSearchController.searchBar.returnKeyType = .done
        uiSearchController.searchBar.searchTextField.clearButtonMode = .whileEditing
        return uiSearchController
    }()

    lazy var searchBar: UISearchBar = self.searchController.searchBar

    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefreshControl), for: .valueChanged)
        return refreshControl
    }()

    lazy var addPasswordUIBarButtonItem: UIBarButtonItem = {
        var addPasswordUIBarButtonItem = UIBarButtonItem()
        let addPasswordButton = UIButton(type: .system)
        let plusImage = UIImage(systemName: "plus.circle", withConfiguration: UIImage.SymbolConfiguration(weight: .regular))
        addPasswordButton.setImage(plusImage, for: .normal)
        addPasswordButton.addTarget(self, action: #selector(self.addPasswordAction), for: .touchDown)
        addPasswordUIBarButtonItem.customView = addPasswordButton
        return addPasswordUIBarButtonItem
    }()

    lazy var gestureRecognizer: UILongPressGestureRecognizer = {
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction))
        recognizer.minimumPressDuration = 0.6
        return recognizer
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        searchBar.delegate = self
        configureTableView(in: parentPasswordEntity)
        configureNotification()
        configureSearchBar()
        configureNavigationBar()
        requestNotificationPermission()
    }

    private func requestNotificationPermission() {
        // Ask for permission to receive notifications
        let notificationCenter = UNUserNotificationCenter.current()
        let permissionOptions = UNAuthorizationOptions(arrayLiteral: .alert)
        notificationCenter.requestAuthorization(options: permissionOptions) { _, _ in }

        // Register notification action
        let copyAction = UNNotificationAction(
            identifier: Globals.otpNotificationCopyAction,
            title: "CopyToPasteboard".localize(),
            options: UNNotificationActionOptions(rawValue: 0)
        )
        let otpCategory = UNNotificationCategory(
            identifier: Globals.otpNotificationCategory,
            actions: [copyAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "",
            options: []
        )
        notificationCenter.setNotificationCategories([otpCategory])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.delegate = self
        configureNavigationItem()
        configureTabBarItem()
        configureNavigationBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let text = searchText, !text.isEmpty {
            DispatchQueue.main.async {
                self.searchBar.text = text
                self.searchController.isActive = true
                self.searchBar.becomeFirstResponder()
            }
        }
    }

    private func configureSearchBar() {
        if Defaults.isShowFolderOn {
            searchBar.scopeButtonTitles = SearchBarScope.allCases.map(\.localizedName)
        } else {
            searchBar.scopeButtonTitles = nil
        }
    }

    private func configureTableView(in dir: PasswordEntity?) {
        configureTableViewDataSource(in: dir, isShowFolder: Defaults.isShowFolderOn)
        tableView.addGestureRecognizer(gestureRecognizer)
        tableView.delegate = self
        tableView.contentInset.top = 8
        let atribbutedTitle = "LastSynced".localize() + ": \(PasswordStore.shared.lastSyncedTimeString)"
        refreshControl.attributedTitle = NSAttributedString(string: atribbutedTitle)
        tableView.refreshControl = refreshControl
    }

    private func configureTableViewDataSource(in dir: PasswordEntity?, isShowFolder: Bool) {
        var passwordTableEntries: [PasswordTableEntry]
        if isShowFolder {
            passwordTableEntries = PasswordStore.shared.fetchPasswordEntityCoreData(parent: dir).compactMap { PasswordTableEntry($0) }
        } else {
            passwordTableEntries = PasswordStore.shared.fetchPasswordEntityCoreData(withDir: false).compactMap { PasswordTableEntry($0) }
        }
        dataSource = PasswordNavigationDataSource(entries: passwordTableEntries)
        tableView.dataSource = dataSource
    }

    private func configureTabBarItem() {
        guard let tabBarItem = navigationController?.tabBarItem else {
            return
        }

        let numberOfLocalCommits = PasswordStore.shared.numberOfLocalCommits
        if numberOfLocalCommits != 0 {
            tabBarItem.badgeValue = "\(numberOfLocalCommits)"
        } else {
            tabBarItem.badgeValue = nil
        }
    }

    private func configureNavigationItem() {
        if isRootViewController() {
            navigationItem.largeTitleDisplayMode = .automatic
            navigationItem.title = "PasswordStore".localize()
        } else {
            navigationItem.largeTitleDisplayMode = .never
            navigationItem.title = parentPasswordEntity?.getName()
        }
        if viewingUnsyncedPasswords {
            navigationItem.title = "Unsynced"
        }

        navigationItem.hidesSearchBarWhenScrolling = false
        navigationItem.rightBarButtonItem = addPasswordUIBarButtonItem
        navigationItem.searchController = searchController
    }

    private func configureNavigationBar() {
        guard let navigationBar = navigationController?.navigationBar else {
            return
        }

        guard PasswordStore.shared.numberOfLocalCommits != 0 else {
            return
        }

        let tapNavigationBarGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapNavigationBar))
        tapNavigationBarGestureRecognizer.cancelsTouchesInView = false
        navigationBar.addGestureRecognizer(tapNavigationBarGestureRecognizer)
    }

    private func isRootViewController() -> Bool {
        navigationController?.viewControllers.count == 1
    }

    private func configureNotification() {
        let notificationCenter = NotificationCenter.default
        // Reset the data table if some password (maybe another one) has been updated.
        notificationCenter.addObserver(self, selector: #selector(actOnPossiblePasswordStoreUpdate), name: .passwordStoreUpdated, object: nil)
        // Reset the data table if the disaply settings have been changed.
        notificationCenter.addObserver(self, selector: #selector(actOnReloadTableViewRelatedNotification), name: .passwordDisplaySettingChanged, object: nil)
        // Search entrypoint for home screen quick action.
        notificationCenter.addObserver(self, selector: #selector(actOnSearchNotification), name: .passwordSearch, object: nil)
        // A Siri shortcut can change the state of the app in the background. Hence, reload when opening the app.
        notificationCenter.addObserver(self, selector: #selector(actOnPossiblePasswordStoreUpdate), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    @objc
    func addPasswordAction(_: Any?) {
        if shouldPerformSegue(withIdentifier: "addPasswordSegue", sender: self) {
            performSegue(withIdentifier: "addPasswordSegue", sender: self)
        }
    }

    @objc
    func didTapNavigationBar(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: navigationController?.navigationBar)
        let hitView = navigationController?.navigationBar.hitTest(location, with: nil)
        guard String(describing: hitView).contains("UINavigationBarContentView") else {
            return
        }

        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let allAction = UIAlertAction(title: "All Passwords", style: .default) { _ in
            self.configureTableView(in: self.parentPasswordEntity)
            self.tableView.reloadData()
            self.viewingUnsyncedPasswords = false
            self.configureNavigationItem()
        }
        let unsyncedAction = UIAlertAction(title: "Unsynced Passwords", style: .default) { _ in
            self.dataSource?.showUnsyncedTableEntries()
            self.tableView.reloadData()
            self.viewingUnsyncedPasswords = true
            self.configureNavigationItem()
        }
        let cancelAction = UIAlertAction.cancel()

        alertController.addAction(allAction)
        alertController.addAction(unsyncedAction)
        alertController.addAction(cancelAction)

        present(alertController, animated: true)
    }

    @objc
    func longPressAction(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == UIGestureRecognizer.State.began {
            let touchPoint = gesture.location(in: tableView)
            if let indexPath = tableView.indexPathForRow(at: touchPoint) {
                guard let dataSource = dataSource else {
                    return
                }
                let passwordTableEntry = dataSource.getPasswordTableEntry(at: indexPath)
                if passwordTableEntry.isDir {
                    return
                }
                passwordManager.providePasswordPasteboard(with: passwordTableEntry.passwordEntity.getPath())
            }
        }
    }

    @objc
    func actOnSearchNotification() {
        searchBar.becomeFirstResponder()
    }

    @objc
    func handleRefreshControl() {
        syncPasswords()
        DispatchQueue.main.async {
            self.refreshControl.endRefreshing()
        }
    }
}

extension PasswordNavigationViewController: UITableViewDelegate {
    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let dataSource = dataSource else {
            return
        }
        let entry = dataSource.getPasswordTableEntry(at: indexPath)
        if entry.isDir {
            showDir(in: entry)
        } else {
            showPasswordDetail(at: entry)
        }
        searchController.isActive = false
    }

    func showDir(in entry: PasswordTableEntry) {
        let passwordNavigationViewController = UIStoryboard.passwordNavigationViewController
        passwordNavigationViewController.parentPasswordEntity = entry.passwordEntity
        navigationController?.pushViewController(passwordNavigationViewController, animated: true)
    }

    func showPasswordDetail(at entry: PasswordTableEntry) {
        let segueIdentifier = "showPasswordDetail"
        let sender = entry.passwordEntity
        if shouldPerformSegue(withIdentifier: segueIdentifier, sender: sender) {
            performSegue(withIdentifier: segueIdentifier, sender: sender)
        }
    }

    func tableView(_: UITableView, estimatedHeightForRowAt _: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        UITableView.automaticDimension
    }

    func tableView(_: UITableView, estimatedHeightForHeaderInSection _: Int) -> CGFloat {
        UITableView.automaticDimension
    }
}

extension PasswordNavigationViewController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showPasswordDetail" {
            if let viewController = segue.destination as? PasswordDetailTableViewController {
                viewController.passwordEntity = sender as? PasswordEntity
            }
        } else if segue.identifier == "addPasswordSegue" {
            if let navController = segue.destination as? UINavigationController,
               let viewController = navController.topViewController as? AddPasswordTableViewController,
               let path = parentPasswordEntity?.getPath() {
                viewController.defaultDirPrefix = "\(path)/"
            }
        }
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender _: Any?) -> Bool {
        if identifier == "showPasswordDetail" {
            guard Defaults.isYubiKeyEnabled || PGPAgent.shared.isPrepared else {
                Utils.alert(title: "CannotShowPassword".localize(), message: "PgpKeyNotSet.".localize(), controller: self)
                return false
            }
        } else if identifier == "addPasswordSegue" {
            guard PGPAgent.shared.isPrepared, PasswordStore.shared.storeRepository != nil else {
                Utils.alert(title: "CannotAddPassword".localize(), message: "MakeSurePgpAndGitProperlySet.".localize(), controller: self)
                return false
            }
        }
        return true
    }

    @IBAction
    private func cancelAddPassword(segue _: UIStoryboardSegue) {}

    @IBAction
    private func cancelEditPassword(segue _: UIStoryboardSegue) {}

    @IBAction
    private func saveEditPassword(segue _: UIStoryboardSegue) {}

    @IBAction
    private func saveAddPassword(segue: UIStoryboardSegue) {
        if let controller = segue.source as? AddPasswordTableViewController {
            passwordManager.addPassword(with: controller.password!)
        }
    }
}

extension PasswordNavigationViewController {
    @objc
    func actOnReloadTableViewRelatedNotification() {
        DispatchQueue.main.async {
            self.navigationController?.popToRootViewController(animated: true)
            self.resetViews()
        }
    }

    @objc
    func actOnPossiblePasswordStoreUpdate() {
        DispatchQueue.main.async {
            if let path = self.parentPath {
                // reload parent because all PasswordEntities are re-created on PasswordStore update
                self.parentPasswordEntity = PasswordStore.shared.fetchPasswordEntity(with: path)

                // pop to the root controller if the parent does not exist anymore
                if self.parentPasswordEntity == nil {
                    self.navigationController?.popToRootViewController(animated: true)
                }
            }

            self.resetViews()
        }
    }

    func resetViews() {
        configureTableView(in: parentPasswordEntity)
        tableView.reloadData()
        configureNavigationItem()
        configureTabBarItem()
        configureNavigationBar()
        configureSearchBar()
    }
}

extension PasswordNavigationViewController: UISearchBarDelegate {
    func search(matching text: String) {
        searchText = text
        dataSource?.showTableEntries(matching: text)
        tableView.reloadData()
    }

    func activateSearch(_ selectedScope: Int?) {
        if selectedScope == SearchBarScope.all.rawValue {
            configureTableViewDataSource(in: nil, isShowFolder: false)
        } else {
            configureTableViewDataSource(in: parentPasswordEntity, isShowFolder: true)
        }
        dataSource?.isSearchActive = true
        tableView.reloadData()
    }

    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        activateSearch(selectedScope)
        search(matching: searchBar.text ?? "")
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        if Defaults.searchDefault == .all {
            searchBar.selectedScopeButtonIndex = SearchBarScope.all.rawValue
        } else {
            searchBar.selectedScopeButtonIndex = SearchBarScope.current.rawValue
        }
        activateSearch(searchBar.selectedScopeButtonIndex)
        search(matching: searchBar.text ?? "")
    }

    func searchBar(_: UISearchBar, textDidChange searchText: String) {
        search(matching: searchText)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func searchBarCancelButtonClicked(_: UISearchBar) {
        cancelSearch()
    }

    func cancelSearch() {
        configureTableView(in: parentPasswordEntity)
        dataSource?.isSearchActive = false
        searchText = nil
        tableView.reloadData()
    }
}

extension PasswordNavigationViewController: UITabBarControllerDelegate {
    func tabBarController(_: UITabBarController, didSelect viewController: UIViewController) {
        if viewController == navigationController {
            let currentTime = Date().timeIntervalSince1970
            let duration = currentTime - tapTabBarTime
            tapTabBarTime = currentTime
            if duration < 0.35, tableView.numberOfSections > 0 {
                let topIndexPath = IndexPath(row: 0, section: 0)
                tableView.scrollToRow(at: topIndexPath, at: .bottom, animated: true)
                tapTabBarTime = 0
            }
        }
    }
}

extension PasswordNavigationViewController: PasswordAlertPresenter {
    private func syncPasswords() {
        guard PasswordStore.shared.repositoryExists() else {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(800)) {
                Utils.alert(title: "Error".localize(), message: "NoPasswordStore.".localize(), controller: self, completion: nil)
            }
            return
        }
        SVProgressHUD.setDefaultMaskType(.black)
        SVProgressHUD.setDefaultStyle(.light)
        SVProgressHUD.show(withStatus: "SyncingPasswordStore".localize())
        let keychain = AppKeychain.shared
        var gitCredential: GitCredential {
            GitCredential.from(
                authenticationMethod: Defaults.gitAuthenticationMethod,
                userName: Defaults.gitUsername,
                keyStore: keychain
            )
        }
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            do {
                let pullOptions = gitCredential.getCredentialOptions(passwordProvider: present)
                try PasswordStore.shared.pullRepository(options: pullOptions) { git_transfer_progress, _ in
                    DispatchQueue.main.async {
                        SVProgressHUD.showProgress(Float(git_transfer_progress.pointee.received_objects) / Float(git_transfer_progress.pointee.total_objects), status: "PullingFromRemoteRepository".localize())
                    }
                }
                if PasswordStore.shared.numberOfLocalCommits > 0 {
                    let pushOptions = gitCredential.getCredentialOptions(passwordProvider: present)
                    try PasswordStore.shared.pushRepository(options: pushOptions) { current, total, _, _ in
                        DispatchQueue.main.async {
                            SVProgressHUD.showProgress(Float(current) / Float(total), status: "PushingToRemoteRepository".localize())
                        }
                    }
                }
                DispatchQueue.main.async {
                    SVProgressHUD.showSuccess(withStatus: "Done".localize())
                    SVProgressHUD.dismiss(withDelay: 1)
                }
            } catch {
                gitCredential.delete()
                DispatchQueue.main.async {
                    SVProgressHUD.dismiss()
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
}
