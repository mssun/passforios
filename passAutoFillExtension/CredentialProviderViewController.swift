//
//  CredentialProviderViewController.swift
//  passAutoFillExtension
//
//  Created by Yishi Lin on 2018/9/24.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

import AuthenticationServices
import passKit

fileprivate class PasswordsTableEntry : NSObject {
    var title: String
    var categoryText: String
    var categoryArray: [String]
    var passwordEntity: PasswordEntity?
    init(_ entity: PasswordEntity) {
        self.title = entity.name!
        self.categoryText = entity.getCategoryText()
        self.categoryArray = entity.getCategoryArray()
        self.passwordEntity = entity
    }
}

class CredentialProviderViewController: ASCredentialProviderViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    
    private let passwordStore = PasswordStore.shared
    
    private var searchActive = false
    private var passwordsTableEntries: [PasswordsTableEntry] = []
    private var filteredPasswordsTableEntries: [PasswordsTableEntry] = []
    
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
        guard serviceIdentifiers.count > 0 else {
            searchBar.text = ""
            searchBar.becomeFirstResponder()
            searchBarSearchButtonClicked(searchBar)
            return
        }
        
        // get the domain
        var identifier = serviceIdentifiers[0].identifier
        if !identifier.hasPrefix("http://") && !identifier.hasPrefix("https://") {
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

    @IBAction func cancel(_ sender: AnyObject?) {
        self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userCanceled.rawValue))
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
        passwordsTableEntries.removeAll()
        filteredPasswordsTableEntries.removeAll()
        var passwordEntities = [PasswordEntity]()
        passwordEntities = self.passwordStore.fetchPasswordEntityCoreData(withDir: false)
        passwordsTableEntries = passwordEntities.map {
            PasswordsTableEntry($0)
        }
    }
    
    // define cell contents, and set long press action
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "passwordTableViewCell", for: indexPath)
        let entry = getPasswordEntry(by: indexPath)
        if entry.passwordEntity!.synced {
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
        
        guard self.passwordStore.privateKey != nil else {
            Utils.alert(title: "Cannot Copy Password", message: "PGP Key is not set. Please set your PGP Key first.", controller: self, completion: nil)
            return
        }
        
        let passwordEntity = entry.passwordEntity!
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        DispatchQueue.global(qos: .userInteractive).async {
            var decryptedPassword: Password?
            do {
                decryptedPassword = try self.passwordStore.decrypt(passwordEntity: passwordEntity, requestPGPKeyPassphrase: self.requestPGPKeyPassphrase)
                let username = decryptedPassword?.username ?? decryptedPassword?.login ?? ""
                let password = decryptedPassword?.password ?? ""
                DispatchQueue.main.async {// prepare a dictionary to return
                    let passwordCredential = ASPasswordCredential(user: username, password: password)
                    self.extensionContext.completeRequest(withSelectedCredential: passwordCredential, completionHandler: nil)
                }
            } catch {
                print(error)
                DispatchQueue.main.async {
                    // remove the wrong passphrase so that users could enter it next time
                    self.passwordStore.pgpKeyPassphrase = nil
                    Utils.alert(title: "Cannot Copy Password", message: error.localizedDescription, controller: self, completion: nil)
                }
            }
        }
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if searchActive {
            return filteredPasswordsTableEntries.count
        }
        return passwordsTableEntries.count;
    }
    
    private func requestPGPKeyPassphrase() -> String {
        let sem = DispatchSemaphore(value: 0)
        var passphrase = ""
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Passphrase", message: "Please fill in the passphrase of your PGP secret key.", preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: {_ in
                passphrase = alert.textFields!.first!.text!
                sem.signal()
            }))
            alert.addTextField(configurationHandler: {(textField: UITextField!) in
                textField.text = ""
                textField.isSecureTextEntry = true
            })
            self.present(alert, animated: true, completion: nil)
        }
        let _ = sem.wait(timeout: DispatchTime.distantFuture)
        if SharedDefaults[.isRememberPGPPassphraseOn] {
            self.passwordStore.pgpKeyPassphrase = passphrase
        }
        return passphrase
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchActive = false
        self.tableView.reloadData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        if let searchText = searchBar.text, searchText.isEmpty == false {
            filteredPasswordsTableEntries = passwordsTableEntries.filter { entry in
                var matched = false
                matched = matched || entry.title.range(of: searchText, options: .caseInsensitive) != nil
                matched = matched || searchText.range(of: entry.title, options: .caseInsensitive) != nil
                entry.categoryArray.forEach({ (category) in
                    matched = matched || category.range(of: searchText, options: .caseInsensitive) != nil
                    matched = matched || searchText.range(of: category, options: .caseInsensitive) != nil
                })
                return matched
            }
            searchActive = true
        } else {
            searchActive = false
        }
        self.tableView.reloadData()
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchBarSearchButtonClicked(searchBar)
    }
    
    private func getPasswordEntry(by indexPath: IndexPath) -> PasswordsTableEntry {
        if searchActive {
            return filteredPasswordsTableEntries[indexPath.row]
        } else {
            return passwordsTableEntries[indexPath.row]
        }
    }
}
