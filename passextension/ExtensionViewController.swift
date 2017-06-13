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

fileprivate class PasswordsTableEntry : NSObject {
    var title: String
    var passwordEntity: PasswordEntity?
    init(title: String, passwordEntity: PasswordEntity?) {
        self.title = title
        self.passwordEntity = passwordEntity
    }
}

class ExtensionViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, UINavigationBarDelegate {
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    
    private let passwordStore = PasswordStore.shared
    
    private var searchActive = false
    
    // the URL passed to the extension
    private var extensionURL: String?
    
    private var passwordsTableEntries: [PasswordsTableEntry] = []
    private var filteredPasswordsTableEntries: [PasswordsTableEntry] = []
    
    private func initPasswordsTableEntries() {
        passwordsTableEntries.removeAll()
        filteredPasswordsTableEntries.removeAll()
        var passwordEntities = [PasswordEntity]()
        passwordEntities = self.passwordStore.fetchPasswordEntityCoreData(withDir: false)
        passwordsTableEntries = passwordEntities.map {
            PasswordsTableEntry(title: $0.name!, passwordEntity: $0)
        }
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
        
        // search using the extensionContext inputs
        let item = extensionContext?.inputItems.first as! NSExtensionItem
        let provider = item.attachments?.first as! NSItemProvider
        let propertyList = String(kUTTypePropertyList)
        if provider.hasItemConformingToTypeIdentifier(propertyList) {
            provider.loadItem(forTypeIdentifier: propertyList, options: nil, completionHandler: { (item, error) -> Void in
                let dictionary = item as! NSDictionary
                let results = dictionary[NSExtensionJavaScriptPreprocessingResultsKey] as! NSDictionary
                let url = URL(string: (results["url"] as? String)!)?.host
                DispatchQueue.main.async { [weak self] in
                    // force search (set text, set active, force search)
                    self?.searchBar.text = url
                    self?.searchBar.becomeFirstResponder()
                    self?.searchBarSearchButtonClicked((self?.searchBar)!)
                }
            })
        } else {
            print("error")
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
        cell.detailTextLabel?.text = entry.passwordEntity?.getCategoryText()
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
                DispatchQueue.main.async {
                    Utils.copyToPasteboard(textToCopy: decryptedPassword?.password)
                    let title = "Password Copied"
                    let message = "Usename: " + (decryptedPassword?.getUsername() ?? "Unknown") + "\r\n(Remember to clear the clipboard.)"
                    let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
                    alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {_ in
                        // return a dictionary for JavaScript for best-effor fill in
                        let extensionItem = NSExtensionItem()
                        let returnDictionary = [ NSExtensionJavaScriptFinalizeArgumentKey : ["username": decryptedPassword?.getUsername() ?? "", "password": decryptedPassword?.password ?? ""]]
                        extensionItem.attachments = [NSItemProvider(item: returnDictionary as NSSecureCoding, typeIdentifier: String(kUTTypePropertyList))]
                        self.extensionContext!.completeRequest(returningItems: [extensionItem], completionHandler: nil)
                    }))
                    self.present(alert, animated: true, completion: nil)
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
        if searchActive{
            return filteredPasswordsTableEntries.count
        }
        return passwordsTableEntries.count;
    }
    
    private func requestPGPKeyPassphrase() -> String {
        let sem = DispatchSemaphore(value: 0)
        var passphrase = ""
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Passphrase", message: "Please fill in the passphrase of your PGP secret key.", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {_ in
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
        if SharedDefaults[.isRememberPassphraseOn] {
            self.passwordStore.pgpKeyPassphrase = passphrase
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
            let searchTextLowerCased = searchText.lowercased()
            filteredPasswordsTableEntries = passwordsTableEntries.filter { entry in
                let entryTitle = entry.title.lowercased()
                return entryTitle.contains(searchTextLowerCased) || searchTextLowerCased.contains(entryTitle)
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
