//
//  PasswordTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 18/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import SwiftGit2
import Result
import SVProgressHUD

class PasswordTableViewController: UITableViewController {
    private var passwordNameArray = [String]()
    private var passwordEntities: [PasswordEntity]?
    
    func temporaryURL(forPurpose purpose: String) -> URL {
        let globallyUniqueString = ProcessInfo.processInfo.globallyUniqueString
        let path = "\(NSTemporaryDirectory())\(globallyUniqueString)_\(purpose)"
        print("\(NSHomeDirectory())/vault")
        return URL(fileURLWithPath: path)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        passwordEntities = PasswordStore.shared.fetchPasswordEntityCoreData()
        NotificationCenter.default.addObserver(self, selector: #selector(PasswordTableViewController.actOnPasswordUpdatedNotification), name: NSNotification.Name(rawValue: "passwordUpdated"), object: nil)

//        SVProgressHUD.setDefaultMaskType(SVProgressHUDMaskType.black)
//        SVProgressHUD.show(withStatus: "Cloning Password Repository")
//        
//        let remoteRepoURL = URL(string: "https://github.com/mssun/public-password-store.git")
//        let localURL = self.temporaryURL(forPurpose: "public-remote-clone")
//        DispatchQueue.global(qos: .userInitiated).async {
//            let cloneResult = Repository.clone(from: remoteRepoURL!, to: localURL)
//            if case .success(let clonedRepo) = cloneResult {
//                let latestCommit: Result<Commit, NSError> = clonedRepo
//                    .HEAD()
//                    .flatMap { clonedRepo.commit($0.oid) }
//                print("localURL \(localURL.path)")
//                if let commit = latestCommit.value {
//                    print("Latest Commit: \(commit.message) by \(commit.author.name)")
//                } else {
//                    print("Could not get commit: \(latestCommit.error)")
//                }
//                let fd =  FileManager.default
//                fd.enumerator(atPath: localURL.path)?.forEach({ (e) in
//                    if let e = e as? String, let url = URL(string: e) {
//                        if url.pathExtension == "gpg" {
//                            self.passwordNameArray.append(url.lastPathComponent);
//                        }
//                    }
//                })
//            }
//            DispatchQueue.main.async {
//                SVProgressHUD.dismiss()
//                self.tableView.reloadData()
//            }
//            
//        }
    }
    
    func actOnPasswordUpdatedNotification() {
        passwordEntities = PasswordStore.shared.fetchPasswordEntityCoreData()
        self.tableView.reloadData()
        print("actOnPasswordUpdatedNotification")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return passwordEntities!.count
    }
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "passwordTableViewCell", for: indexPath)
        cell.textLabel?.text = passwordEntities![indexPath.row].name
        return cell
    }
    
}
