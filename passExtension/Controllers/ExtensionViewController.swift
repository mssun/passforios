//
//  PasswordsViewController.swift
//  pass
//
//  Created by Yishi Lin on 13/6/17.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import MobileCoreServices
import passKit

class ExtensionViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, UINavigationBarDelegate {
    @IBOutlet var searchBar: UISearchBar!
    @IBOutlet var tableView: UITableView!

    private let passwordStore = PasswordStore.shared
    private let keychain = AppKeychain.shared

    private var searchActive = false
    private var passwordsTableEntries: [PasswordTableEntry] = []
    private var filteredPasswordsTableEntries: [PasswordTableEntry] = []

    enum Action {
        case findLogin, fillBrowser, unknown
    }

    private var extensionAction = Action.unknown

    private lazy var passcodelock: PasscodeExtensionDisplay = {
        let passcodelock = PasscodeExtensionDisplay(extensionContext: self.extensionContext)
        return passcodelock
    }()

    private func initPasswordsTableEntries() {
        filteredPasswordsTableEntries.removeAll()

        let passwordEntities = passwordStore.fetchPasswordEntityCoreData(withDir: false)
        passwordsTableEntries = passwordEntities.map {
            PasswordTableEntry($0)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        passcodelock.presentPasscodeLockIfNeeded(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // prepare
        searchBar.delegate = self
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UINib(nibName: "PasswordWithFolderTableViewCell", bundle: nil), forCellReuseIdentifier: "passwordWithFolderTableViewCell")

        // initialize table entries
        initPasswordsTableEntries()

        // get the provider
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            return
        }

        for extensionItem in extensionItems {
            if let itemProviders = extensionItem.attachments {
                for provider in itemProviders {
                    // search using the extensionContext inputs
                    if provider.hasItemConformingToTypeIdentifier(OnePasswordExtensionActions.findLogin) {
                        provider.loadItem(forTypeIdentifier: OnePasswordExtensionActions.findLogin, options: nil) { (item, _) -> Void in
                            let dictionary = item as! NSDictionary
                            var url: String?
                            if var urlString = dictionary[OnePasswordExtensionKey.URLStringKey] as? String {
                                if !urlString.hasPrefix("http://"), !urlString.hasPrefix("https://") {
                                    urlString = "http://" + urlString
                                }
                                url = URL(string: urlString)?.host
                            }
                            DispatchQueue.main.async { [weak self] in
                                self?.extensionAction = .findLogin
                                // force search (set text, set active, force search)
                                self?.searchBar.text = url
                                self?.searchBar.becomeFirstResponder()
                                self?.searchBarSearchButtonClicked((self?.searchBar)!)
                            }
                        }
                    } else if provider.hasItemConformingToTypeIdentifier(kUTTypePropertyList as String) {
                        provider.loadItem(forTypeIdentifier: kUTTypePropertyList as String, options: nil) { (item, _) -> Void in
                            var url: String?
                            if let dictionary = item as? NSDictionary,
                                let results = dictionary[NSExtensionJavaScriptPreprocessingResultsKey] as? NSDictionary,
                                var urlString = results[OnePasswordExtensionKey.URLStringKey] as? String {
                                if !urlString.hasPrefix("http://"), !urlString.hasPrefix("https://") {
                                    urlString = "http://" + urlString
                                }
                                url = URL(string: urlString)?.host
                            }
                            DispatchQueue.main.async { [weak self] in
                                self?.extensionAction = .fillBrowser
                                // force search (set text, set active, force search)
                                self?.searchBar.text = url
                                self?.searchBar.becomeFirstResponder()
                                self?.searchBarSearchButtonClicked((self?.searchBar)!)
                            }
                        }
                    } else if provider.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                        provider.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { (item, _) -> Void in
                            let url = (item as? NSURL)!.host
                            DispatchQueue.main.async { [weak self] in
                                self?.extensionAction = .fillBrowser
                                // force search (set text, set active, force search)
                                self?.searchBar.text = url
                                self?.searchBar.becomeFirstResponder()
                                self?.searchBarSearchButtonClicked((self?.searchBar)!)
                            }
                        }
                    }
                }
            }
        }
    }

    // define cell contents, and set long press action
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "passwordTableViewCell", for: indexPath)
        let entry = getPasswordEntry(by: indexPath)
        if entry.synced {
            cell.textLabel?.text = entry.title
        } else {
            cell.textLabel?.text = "↻ \(entry.title)"
        }
        cell.accessoryType = .none
        cell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .footnote)
        cell.detailTextLabel?.text = entry.categoryText
        return cell
    }

    // select row -> extension returns (with username and password)
    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        let entry = getPasswordEntry(by: indexPath)

        guard PGPAgent.shared.isPrepared else {
            Utils.alert(title: "CannotCopyPassword".localize(), message: "PgpKeyNotSet.".localize(), controller: self, completion: nil)
            return
        }

        let passwordEntity = entry.passwordEntity
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        decryptPassword(passwordEntity: passwordEntity)
    }

    private func decryptPassword(passwordEntity: PasswordEntity, keyID: String? = nil) {
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                let requestPGPKeyPassphrase = Utils.createRequestPGPKeyPassphraseHandler(controller: self)
                let decryptedPassword = try self.passwordStore.decrypt(passwordEntity: passwordEntity, keyID: keyID, requestPGPKeyPassphrase: requestPGPKeyPassphrase)

                let username = decryptedPassword.getUsernameForCompletion()
                let password = decryptedPassword.password
                DispatchQueue.main.async {
                    // prepare a dictionary to return
                    switch self.extensionAction {
                    case .findLogin:
                        let extensionItem = NSExtensionItem()
                        var returnDictionary = [
                            OnePasswordExtensionKey.usernameKey: username,
                            OnePasswordExtensionKey.passwordKey: password,
                        ]
                        if let totpPassword = decryptedPassword.currentOtp {
                            returnDictionary[OnePasswordExtensionKey.totpKey] = totpPassword
                        }
                        extensionItem.attachments = [NSItemProvider(item: returnDictionary as NSSecureCoding, typeIdentifier: String(kUTTypePropertyList))]
                        self.extensionContext!.completeRequest(returningItems: [extensionItem], completionHandler: nil)
                    case .fillBrowser:
                        Utils.copyToPasteboard(textToCopy: decryptedPassword.password)
                        // return a dictionary for JavaScript for best-effor fill in
                        let extensionItem = NSExtensionItem()
                        let returnDictionary = [NSExtensionJavaScriptFinalizeArgumentKey: ["username": username, "password": password]]
                        extensionItem.attachments = [NSItemProvider(item: returnDictionary as NSSecureCoding, typeIdentifier: String(kUTTypePropertyList))]
                        self.extensionContext?.completeRequest(returningItems: [extensionItem], completionHandler: nil)
                    default:
                        self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                    }
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

                    self.present(alert, animated: true, completion: nil)
                }
            } catch {
                DispatchQueue.main.async {
                    Utils.alert(title: "CannotCopyPassword".localize(), message: error.localizedDescription, controller: self, completion: nil)
                }
            }
        }
    }

    func numberOfSectionsInTableView(tableView _: UITableView) -> Int {
        1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        if searchActive {
            return filteredPasswordsTableEntries.count
        }
        return passwordsTableEntries.count
    }

    @IBAction
    func cancelExtension(_: Any) {
        extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchActive = false
        tableView.reloadData()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        if let searchText = searchBar.text, searchText.isEmpty == false {
            filteredPasswordsTableEntries = passwordsTableEntries.filter { $0.match(searchText) }
            searchActive = true
        } else {
            searchActive = false
        }
        tableView.reloadData()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange _: String) {
        searchBarSearchButtonClicked(searchBar)
    }

    private func getPasswordEntry(by indexPath: IndexPath) -> PasswordTableEntry {
        if searchActive {
            return filteredPasswordsTableEntries[indexPath.row]
        } else {
            return passwordsTableEntries[indexPath.row]
        }
    }
}
