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
    let passwordStore = PasswordStore.shared

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if tableView.cellForRow(at: indexPath) == eraseDataTableViewCell {
            let alert = UIAlertController(title: "Erase Password Store Data?", message: "This will delete all local data and settings. Password store data on your remote server will not be affected.", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "Erase Password Data", style: UIAlertActionStyle.destructive, handler: {[unowned self] (action) -> Void in
                SVProgressHUD.show(withStatus: "Erasing ...")
                self.passwordStore.erase()
                self.navigationController!.popViewController(animated: true)
                SVProgressHUD.showSuccess(withStatus: "Done")
                SVProgressHUD.dismiss(withDelay: 1)
            }))
            alert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.cancel, handler:nil))
            self.present(alert, animated: true, completion: nil)
        } else if tableView.cellForRow(at: indexPath) == discardChangesTableViewCell {
            let alert = UIAlertController(title: "Discard All Changes?", message: "Do you want to permanently discard all changes to the local copy of your password data? You cannot undo this action.", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "Discard All Changes", style: UIAlertActionStyle.destructive, handler: {[unowned self] (action) -> Void in
                DispatchQueue.global(qos: .userInitiated).async {
                    SVProgressHUD.show(withStatus: "Resetting ...")
                    DispatchQueue.main.async {
                        do {
                            let numberDiscarded = try self.passwordStore.reset()
                            self.navigationController!.popViewController(animated: true)
                            switch numberDiscarded {
                            case 0:
                                SVProgressHUD.showSuccess(withStatus: "No local commits")
                            case 1:
                                SVProgressHUD.showSuccess(withStatus: "Discarded 1 commit")
                            default:
                                SVProgressHUD.showSuccess(withStatus: "Discarded \(numberDiscarded) commits")
                            }
                            SVProgressHUD.dismiss(withDelay: 1)
                        } catch {
                            Utils.alert(title: "Error", message: error.localizedDescription, controller: self, completion: nil)
                        }
                    }
                }
                
            }))
            alert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.cancel, handler:nil))
            self.present(alert, animated: true, completion: nil)
        }
    }

}
