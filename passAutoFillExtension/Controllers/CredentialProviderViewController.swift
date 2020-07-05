//
//  CredentialProviderViewController.swift
//  passAutoFillExtension
//
//  Created by Yishi Lin on 2018/9/24.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

import AuthenticationServices
import passKit

class CredentialProviderViewController: ASCredentialProviderViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {
    @IBOutlet var searchBar: UISearchBar!
    @IBOutlet var tableView: UITableView!

    private let passwordStore = PasswordStore.shared
    private let keychain = AppKeychain.shared

    private var searchActive = false
    private var passwordsTableEntries: [PasswordTableEntry] = []
    private var filteredPasswordsTableEntries: [PasswordTableEntry] = []

    private lazy var passcodelock: PasscodeExtensionDisplay = {
        let passcodelock = PasscodeExtensionDisplay(extensionContext: self.extensionContext)
        return passcodelock
    }()

    /*
      Prepare your UI to list available credentials for the user to choose from. The items in
      'serviceIdentifiers' describe the service the user is logging in to, so your extension can
      prioritize the most relevant credentials in the list.
     */
    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        // clean up the search bar
        guard !serviceIdentifiers.isEmpty else {
            searchBar.text = ""
            searchBar.becomeFirstResponder()
            searchBarSearchButtonClicked(searchBar)
            return
        }

        // get the domain
        var identifier = serviceIdentifiers[0].identifier
        if !identifier.hasPrefix("http://"), !identifier.hasPrefix("https://") {
            identifier = "http://" + identifier
        }
        let url = URL(string: identifier)?.host ?? ""

        // "click" search
        searchBar.text = url
        searchBar.becomeFirstResponder()
        searchBarSearchButtonClicked(searchBar)
    }

    /*
      Implement this method if your extension support
      s showing credentials in the QuickType bar.
      When the user selects a credential from your app, this method will be called with the
      ASPasswordCredentialIdentity your app has previously saved to the ASCredentialIdentityStore.
      Provide the password by completing the extension request with the associated ASPasswordCredential.
      If using the credential would require showing custom UI for authenticating the user, cancel
      the request with error code ASExtensionError.userInteractionRequired.

     override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
         let databaseIsUnlocked = true
         if (databaseIsUnlocked) {
             let passwordCredential = ASPasswordCredential(user: "j_appleseed", password: "apple1234")
             self.extensionContext.completeRequest(withSelectedCredential: passwordCredential, completionHandler: nil)
         } else {
             self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code:ASExtensionError.userInteractionRequired.rawValue))
         }
     }
     */

    /*
      Implement this method if provideCredentialWithoutUserInteraction(for:) can fail with
      ASExtensionError.userInteractionRequired. In this case, the system may present your extension's
      UI and call this method. Show appropriate UI for authenticating the user then provide the password
      by completing the extension request with the associated ASPasswordCredential.

     override func prepareInterfaceToProvideCredential(for credentialIdentity: ASPasswordCredentialIdentity) {
     }
     */

    @IBAction
    private func cancel(_: AnyObject?) {
        extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userCanceled.rawValue))
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
    }

    private func initPasswordsTableEntries() {
        filteredPasswordsTableEntries.removeAll()

        let passwordEntities = passwordStore.fetchPasswordEntityCoreData(withDir: false)
        passwordsTableEntries = passwordEntities.compactMap {
            PasswordTableEntry($0)
        }
    }

    // define cell contents
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "passwordTableViewCell", for: indexPath)
        let entry = getPasswordEntry(by: indexPath)
        if entry.passwordEntity.synced {
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
                    let passwordCredential = ASPasswordCredential(user: username, password: password)
                    self.extensionContext.completeRequest(withSelectedCredential: passwordCredential)
                }
            } catch let AppError.PgpPrivateKeyNotFound(key) {
                DispatchQueue.main.async {
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

    func numberOfSectionsInTableView(tableView _: UITableView) -> Int {
        1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        if searchActive {
            return filteredPasswordsTableEntries.count
        }
        return passwordsTableEntries.count
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
