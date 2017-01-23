//
//  SettingsTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 18/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import SVProgressHUD
import CoreData
import SwiftyUserDefaults

class SettingsTableViewController: UITableViewController {
        
    @IBOutlet weak var pgpKeyTableViewCell: UITableViewCell!
    
    @IBAction func cancel(segue: UIStoryboardSegue) {
    }
    
    @IBAction func save(segue: UIStoryboardSegue) {
        if let controller = segue.source as? GitServerSettingTableViewController {
            if Defaults[.gitRepositoryURL] == nil || controller.gitRepositoryURLTextField.text != Defaults[.gitRepositoryURL]!.absoluteString {
                Defaults[.gitRepositoryURL] = URL(string: controller.gitRepositoryURLTextField.text!)
                
                SVProgressHUD.setDefaultMaskType(.black)
                SVProgressHUD.show(withStatus: "Cloning Remote Repository")
                
                DispatchQueue.global(qos: .userInitiated).async {
                    let ret = PasswordStore.shared.cloneRepository(remoteRepoURL: Defaults[.gitRepositoryURL]!)
                    
                    DispatchQueue.main.async {
                        if ret {
                                SVProgressHUD.dismiss()
                                SVProgressHUD.setMaximumDismissTimeInterval(1)
                                SVProgressHUD.showSuccess(withStatus: "Success")
                                NotificationCenter.default.post(Notification(name: Notification.Name("passwordUpdated")))
                        } else {
                                SVProgressHUD.showError(withStatus: "Error")
                        }
                    }
                }
            }
        } else if let controller = segue.source as? PGPKeySettingTableViewController {
            if Defaults[.pgpKeyURL] != URL(string: controller.pgpKeyURLTextField.text!) {
                Defaults[.pgpKeyURL] = URL(string: controller.pgpKeyURLTextField.text!)
                Defaults[.pgpKeyPassphrase] = controller.pgpKeyPassphraseTextField.text!
                
                SVProgressHUD.setDefaultMaskType(.black)
                SVProgressHUD.show(withStatus: "Fetching PGP Key")
                DispatchQueue.global(qos: .userInitiated).async {
                    let ret = PasswordStore.shared.initPGP(pgpKeyURL: Defaults[.pgpKeyURL]!, pgpKeyLocalPath: Globals.shared.secringPath)
                    
                    DispatchQueue.main.async {
                        if ret {
                            SVProgressHUD.showSuccess(withStatus: "Success")
                        } else {
                            SVProgressHUD.showError(withStatus: "Error")
                    }
                    }
                }
            }
            
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if Defaults[.pgpKeyID] == "" {
            pgpKeyTableViewCell.detailTextLabel?.text = "Not Set"
        } else {
            pgpKeyTableViewCell.detailTextLabel?.text = Defaults[.pgpKeyID]
        }
    }
}
