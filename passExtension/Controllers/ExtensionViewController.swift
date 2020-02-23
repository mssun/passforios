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
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!

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
        
        let passwordEntities = self.passwordStore.fetchPasswordEntityCoreData(withDir: false)
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
                        provider.loadItem(forTypeIdentifier: OnePasswordExtensionActions.findLogin, options: nil, completionHandler: { (item, error) -> Void in
                            let dictionary = item as! NSDictionary
                            var url: String?
                            if var urlString = dictionary[OnePasswordExtensionKey.URLStringKey] as? String {
                                if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
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
                        })
                    }
                    else if provider.hasItemConformingToTypeIdentifier(kUTTypePropertyList as String) {
                        provider.loadItem(forTypeIdentifier: kUTTypePropertyList as String, options: nil, completionHandler: { (item, error) -> Void in
                            var url: String?
                            if let dictionary = item as? NSDictionary,
                                let results = dictionary[NSExtensionJavaScriptPreprocessingResultsKey] as? NSDictionary,
                                var urlString = results[OnePasswordExtensionKey.URLStringKey] as? String {
                                if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
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
                        })
                    } else if provider.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                        provider.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil, completionHandler: { (item, error) -> Void in
                            let url = (item as? NSURL)!.host
                            DispatchQueue.main.async { [weak self] in
                                self?.extensionAction = .fillBrowser
                                // force search (set text, set active, force search)
                                self?.searchBar.text = url
                                self?.searchBar.becomeFirstResponder()
                                self?.searchBarSearchButtonClicked((self?.searchBar)!)
                            }
                        })
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
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let entry = getPasswordEntry(by: indexPath)

        guard PGPAgent.shared.isPrepared else {
            Utils.alert(title: "CannotCopyPassword".localize(), message: "PgpKeyNotSet.".localize(), controller: self, completion: nil)
            return
        }

        let passwordEntity = entry.passwordEntity
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        DispatchQueue.global(qos: .userInteractive).async {
            var decryptedPassword: Password?
            do {
                decryptedPassword = try self.passwordStore.decrypt(passwordEntity: passwordEntity, requestPGPKeyPassphrase: self.requestPGPKeyPassphrase)
                let username = decryptedPassword?.username ?? decryptedPassword?.login ?? decryptedPassword?.nameFromPath ?? ""
                let password = decryptedPassword?.password ?? ""
                DispatchQueue.main.async {// prepare a dictionary to return
                    switch self.extensionAction {
                    case .findLogin:
                        let extensionItem = NSExtensionItem()
                        var returnDictionary = [OnePasswordExtensionKey.usernameKey: username,
                                                OnePasswordExtensionKey.passwordKey: password]
                        if let totpPassword = decryptedPassword?.currentOtp {
                            returnDictionary[OnePasswordExtensionKey.totpKey] = totpPassword
                        }
                        extensionItem.attachments = [NSItemProvider(item: returnDictionary as NSSecureCoding, typeIdentifier: String(kUTTypePropertyList))]
                        self.extensionContext!.completeRequest(returningItems: [extensionItem], completionHandler: nil)
                    case .fillBrowser:
                        Utils.copyToPasteboard(textToCopy: decryptedPassword?.password)
                        // return a dictionary for JavaScript for best-effor fill in
                        let extensionItem = NSExtensionItem()
                        let returnDictionary = [NSExtensionJavaScriptFinalizeArgumentKey : ["username": username, "password": password]]
                        extensionItem.attachments = [NSItemProvider(item: returnDictionary as NSSecureCoding, typeIdentifier: String(kUTTypePropertyList))]
                        self.extensionContext!.completeRequest(returningItems: [extensionItem], completionHandler: nil)
                    default:
                        self.extensionContext!.completeRequest(returningItems: nil, completionHandler: nil)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    Utils.alert(title: "CannotCopyPassword".localize(), message: error.localizedDescription, controller: self, completion: nil)
                }
            }
        }
    }


    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if searchActive{
            return filteredPasswordsTableEntries.count
        }
        return passwordsTableEntries.count;
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

    @IBAction func cancelExtension(_ sender: Any) {
        extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchActive = false
        self.tableView.reloadData()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        if let searchText = searchBar.text, searchText.isEmpty == false {
            filteredPasswordsTableEntries = passwordsTableEntries.filter {$0.match(searchText)}
            searchActive = true
        } else {
            searchActive = false
        }
        self.tableView.reloadData()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
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
