//
//  AdvancedSettingsTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 7/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import SVProgressHUD

class AdvancedSettingsTableViewController: UITableViewController {

    @IBOutlet weak var eraseDataTableViewCell: UITableViewCell!
    @IBOutlet weak var discardChangesTableViewCell: UITableViewCell!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.cellForRow(at: indexPath) == eraseDataTableViewCell {
            print("erase data")
            let alert = UIAlertController(title: "Erase Password Store Data?", message: "This will delete all local data and settings. Password store data on your remote server will not be affected.", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "Erase Password Data", style: UIAlertActionStyle.destructive, handler: {[unowned self] (action) -> Void in
                SVProgressHUD.show(withStatus: "Erasing ...")
                PasswordStore.shared.erase()
                NotificationCenter.default.post(Notification(name: Notification.Name("passwordStoreErased")))
                self.navigationController!.popViewController(animated: true)
                SVProgressHUD.showSuccess(withStatus: "Done")
                SVProgressHUD.dismiss(withDelay: 1)
            }))
            alert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.cancel, handler:nil))
            self.present(alert, animated: true, completion: nil)
            tableView.deselectRow(at: indexPath, animated: true)
        } else if tableView.cellForRow(at: indexPath) == discardChangesTableViewCell {
            let alert = UIAlertController(title: "Discard All Changes?", message: "Do you want to permanently discard all changes to the local copy of your password data? You cannot undo this action.", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "Discard All Changes", style: UIAlertActionStyle.destructive, handler: {[unowned self] (action) -> Void in
                DispatchQueue.global(qos: .userInitiated).async {
                    SVProgressHUD.show(withStatus: "Resetting ...")
                    DispatchQueue.main.async {
                        do {
                            let numberDiscarded = try PasswordStore.shared.reset()
                            if numberDiscarded > 0 {
                                NotificationCenter.default.post(Notification(name: Notification.Name("passwordStoreChangeDiscarded")))
                            }
                            self.navigationController!.popViewController(animated: true)
                            SVProgressHUD.showSuccess(withStatus: "Discarded \(numberDiscarded) commits")
                            SVProgressHUD.dismiss(withDelay: 1)
                        } catch {
                            DispatchQueue.main.async {
                                SVProgressHUD.showError(withStatus: error.localizedDescription)
                                SVProgressHUD.dismiss(withDelay: 1)
                            }
                        }
                    }
                }
                
            }))
            alert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.cancel, handler:nil))
            self.present(alert, animated: true, completion: nil)
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }

}
