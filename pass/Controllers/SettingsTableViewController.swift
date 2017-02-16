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
import PasscodeLock

class SettingsTableViewController: UITableViewController {
    
    let touchIDSwitch = UISwitch(frame: CGRect.zero)

    @IBOutlet weak var pgpKeyTableViewCell: UITableViewCell!
    @IBOutlet weak var touchIDTableViewCell: UITableViewCell!
    @IBOutlet weak var passcodeTableViewCell: UITableViewCell!
    
    @IBAction func cancel(segue: UIStoryboardSegue) {
    }
    
    @IBAction func save(segue: UIStoryboardSegue) {
        if let controller = segue.source as? PGPKeySettingTableViewController {

            if Defaults[.pgpKeyID] == nil ||
                Defaults[.pgpPrivateKeyURL] != URL(string: controller.pgpPrivateKeyURLTextField.text!) ||
                Defaults[.pgpPublicKeyURL] != URL(string: controller.pgpPublicKeyURLTextField.text!) ||
                Defaults[.pgpKeyPassphrase] != controller.pgpKeyPassphraseTextField.text!
                {
                Defaults[.pgpPrivateKeyURL] = URL(string: controller.pgpPrivateKeyURLTextField.text!)
                Defaults[.pgpPublicKeyURL] = URL(string: controller.pgpPublicKeyURLTextField.text!)
                Defaults[.pgpKeyPassphrase] = controller.pgpKeyPassphraseTextField.text!
                
                SVProgressHUD.setDefaultMaskType(.black)
                SVProgressHUD.setDefaultStyle(.light)
                SVProgressHUD.show(withStatus: "Fetching PGP Key")
                DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
                    do {
                        try PasswordStore.shared.initPGP(pgpPublicKeyURL: Defaults[.pgpPublicKeyURL]!,
                                                         pgpPublicKeyLocalPath: Globals.pgpPublicKeyPath,
                                                         pgpPrivateKeyURL: Defaults[.pgpPrivateKeyURL]!,
                                                         pgpPrivateKeyLocalPath: Globals.pgpPrivateKeyPath)
                        DispatchQueue.main.async {
                            self.pgpKeyTableViewCell.detailTextLabel?.text = Defaults[.pgpKeyID]
                            SVProgressHUD.showSuccess(withStatus: "Success.")
                            SVProgressHUD.dismiss(withDelay: 1)
                            Utils.alert(title: "Remove the Key", message: "Remember to remove the key from the server.", controller: self, completion: nil)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.pgpKeyTableViewCell.detailTextLabel?.text = "Not Set"
                            Defaults[.pgpKeyID] = nil
                            SVProgressHUD.showError(withStatus: error.localizedDescription)
                            SVProgressHUD.dismiss(withDelay: 1)
                        }
                    }
                }
            }
            
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsTableViewController.actOnPasswordStoreErasedNotification), name: NSNotification.Name(rawValue: "passwordStoreErased"), object: nil)
        touchIDSwitch.onTintColor = UIColor(displayP3Red: 0, green: 122.0/255, blue: 1, alpha: 1)
        touchIDTableViewCell.accessoryView = touchIDSwitch
        touchIDSwitch.addTarget(self, action: #selector(touchIDSwitchAction), for: UIControlEvents.valueChanged)
        if Defaults[.pgpKeyID] == "" {
            pgpKeyTableViewCell.detailTextLabel?.text = "Not Set"
        } else {
            pgpKeyTableViewCell.detailTextLabel?.text = Defaults[.pgpKeyID]
        }
        if Defaults[.isTouchIDOn] {
            touchIDSwitch.isOn = true
        } else {
            touchIDSwitch.isOn = false
        }
        if PasscodeLockRepository().hasPasscode {
            self.passcodeTableViewCell.detailTextLabel?.text = "On"
        } else {
            self.passcodeTableViewCell.detailTextLabel?.text = "Off"
            touchIDSwitch.isEnabled = false
        }
    }
    
    func actOnPasswordStoreErasedNotification() {
        pgpKeyTableViewCell.detailTextLabel?.text = "Not Set"
        touchIDSwitch.isOn = false
        self.passcodeTableViewCell.detailTextLabel?.text = "Off"
        Globals.passcodeConfiguration.isTouchIDAllowed = false

        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.passcodeLockPresenter = PasscodeLockPresenter(mainWindow: appDelegate.window, configuration: Globals.passcodeConfiguration)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.cellForRow(at: indexPath) == passcodeTableViewCell {
            if Defaults[.passcodeKey] != nil{
                showPasscodeActionSheet()
            } else {
                setPasscodeLock()
            }
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    func touchIDSwitchAction(uiSwitch: UISwitch) {
        if uiSwitch.isOn {
            Defaults[.isTouchIDOn] = true
            Globals.passcodeConfiguration.isTouchIDAllowed = true
        } else {
            Defaults[.isTouchIDOn] = false
            Globals.passcodeConfiguration.isTouchIDAllowed = false
        }
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.passcodeLockPresenter = PasscodeLockPresenter(mainWindow: appDelegate.window, configuration: Globals.passcodeConfiguration)
    }
    
    func showPasscodeActionSheet() {
        let passcodeChangeViewController = PasscodeLockViewController(state: .change, configuration: Globals.passcodeConfiguration)
        let passcodeRemoveViewController = PasscodeLockViewController(state: .remove, configuration: Globals.passcodeConfiguration)

        let optionMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let removePasscodeAction = UIAlertAction(title: "Remove Passcode", style: .destructive) { [weak self] _ in
            passcodeRemoveViewController.successCallback  = { _ in
                self?.passcodeTableViewCell.detailTextLabel?.text = "Off"
                self?.touchIDSwitch.isEnabled = false
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                appDelegate.passcodeLockPresenter = PasscodeLockPresenter(mainWindow: appDelegate.window, configuration: Globals.passcodeConfiguration)
            }
            self?.present(passcodeRemoveViewController, animated: true, completion: nil)
        }
        
        let changePasscodeAction = UIAlertAction(title: "Change Passcode", style: .default) { [weak self] _ in
            self?.present(passcodeChangeViewController, animated: true, completion: nil)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        optionMenu.addAction(removePasscodeAction)
        optionMenu.addAction(changePasscodeAction)
        optionMenu.addAction(cancelAction)
        self.present(optionMenu, animated: true, completion: nil)
    }
    
    func setPasscodeLock() {
        let passcodeSetViewController = PasscodeLockViewController(state: .set, configuration: Globals.passcodeConfiguration)
        passcodeSetViewController.successCallback = { _ in
            self.passcodeTableViewCell.detailTextLabel?.text = "On"
            self.touchIDSwitch.isEnabled = true
        }
        present(passcodeSetViewController, animated: true, completion: nil)
    }
}
