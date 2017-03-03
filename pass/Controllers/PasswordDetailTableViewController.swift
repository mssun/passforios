//
//  PasswordDetailTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 2/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import FavIcon
import SwiftyUserDefaults
import SVProgressHUD

class PasswordDetailTableViewController: UITableViewController, UIGestureRecognizerDelegate {
    var passwordEntity: PasswordEntity?
    var passwordCategoryText = ""
    var password: Password?
    var passwordImage: UIImage?
    
    let indicatorLable: UILabel = {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 21))
        label.center = CGPoint(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height * 0.382 + 22)
        label.backgroundColor = UIColor.clear
        label.textColor = UIColor.gray
        label.text = "decrypting password"
        label.textAlignment = .center
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        return label
    }()
    
    let indicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        indicator.center = CGPoint(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height * 0.382)
        return indicator
    }()
    
    lazy var editUIBarButtonItem: UIBarButtonItem = {
        let uiBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(pressEdit(_:)))
        return uiBarButtonItem
    }()


    struct TableCell {
        var title: String
        var content: String
        init() {
            title = ""
            content = ""
        }
        
        init(title: String, content: String) {
            self.title = title
            self.content = content
        }
    }
    
    struct TableSection {
        var title: String
        var item: Array<TableCell>
    }
    
    var tableData = Array<TableSection>()
    
    private func generateCategoryText() -> String {
        var passwordCategoryArray: [String] = []
        var parent = passwordEntity?.parent
        while parent != nil {
            passwordCategoryArray.append(parent!.name!)
            parent = parent!.parent
        }
        passwordCategoryArray.reverse()
        return passwordCategoryArray.joined(separator: " > ")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UINib(nibName: "LabelTableViewCell", bundle: nil), forCellReuseIdentifier: "labelCell")
        tableView.register(UINib(nibName: "PasswordDetailTitleTableViewCell", bundle: nil), forCellReuseIdentifier: "passwordDetailTitleTableViewCell")
        
        passwordCategoryText = generateCategoryText()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(PasswordDetailTableViewController.tapMenu(recognizer:)))
        tableView.addGestureRecognizer(tapGesture)
        tapGesture.delegate = self
        
        tableView.contentInset = UIEdgeInsetsMake(-36, 0, 0, 0);
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 52
 
        
        indicator.startAnimating()
        tableView.addSubview(indicator)
        tableView.addSubview(indicatorLable)
        editUIBarButtonItem.isEnabled = false
        navigationItem.rightBarButtonItem = editUIBarButtonItem
        
        if let imageData = passwordEntity?.image {
            let image = UIImage(data: imageData as Data)
            passwordImage = image
        }
        
        var passphrase = ""
        if Defaults[.isRememberPassphraseOn] && PasswordStore.shared.pgpKeyPassphrase != nil {
            passphrase = PasswordStore.shared.pgpKeyPassphrase!
            self.decryptThenShowPassword(passphrase: passphrase)
        } else {
            let alert = UIAlertController(title: "Passphrase", message: "Please fill in the passphrase of your PGP secret key.", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {_ in
                passphrase = alert.textFields!.first!.text!
                self.decryptThenShowPassword(passphrase: passphrase)
            }))
            alert.addTextField(configurationHandler: {(textField: UITextField!) in
                textField.text = ""
                textField.isSecureTextEntry = true
            })
            self.present(alert, animated: true, completion: nil)
        }
        
        
    }
    
    func decryptThenShowPassword(passphrase: String) {
        if Defaults[.isRememberPassphraseOn] {
            PasswordStore.shared.pgpKeyPassphrase = passphrase
        }
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                self.password = try self.passwordEntity!.decrypt(passphrase: passphrase)!
            } catch {
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Cannot Show Password", message: error.localizedDescription, preferredStyle: UIAlertControllerStyle.alert)
                    alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {(UIAlertAction) -> Void in
                        self.navigationController!.popViewController(animated: true)
                    }))
                    self.present(alert, animated: true, completion: nil)
                }
                return
            }
            
            let password = self.password!
            DispatchQueue.main.async { [weak self] in
                self?.showPassword(password: password)
            }
        }
    }
    
    func showPassword(password: Password) {
        setTableData()
        self.tableView.reloadData()
        indicator.stopAnimating()
        indicatorLable.isHidden = true
        editUIBarButtonItem.isEnabled = true
        if let url = password.getURL() {
            if self.passwordEntity?.image == nil{
                self.updatePasswordImage(url: url)
            }
        }
    }
    
    func pressEdit(_ sender: Any?) {
        print("pressEdit")
        performSegue(withIdentifier: "editPasswordSegue", sender: self)
    }
    
    @IBAction func cancelEditPassword(segue: UIStoryboardSegue) {
    
    }
    
    @IBAction func saveEditPassword(segue: UIStoryboardSegue) {
        if self.password!.changed {
            SVProgressHUD.show(withStatus: "Saving")
            DispatchQueue.global(qos: .userInitiated).async {
                PasswordStore.shared.update(passwordEntity: self.passwordEntity!, password: self.password!, progressBlock: { progress in
                    DispatchQueue.main.async {
                        SVProgressHUD.showProgress(progress, status: "Encrypting")
                    }
                })
                DispatchQueue.main.async {
                    self.passwordEntity!.synced = false
                    PasswordStore.shared.saveUpdated(passwordEntity: self.passwordEntity!)
                    NotificationCenter.default.post(Notification(name: Notification.Name("passwordUpdated")))
                    self.setTableData()
                    self.tableView.reloadData()
                    SVProgressHUD.showSuccess(withStatus: "Success")
                    SVProgressHUD.dismiss(withDelay: 1)
                }
            }
        }
    }
    
    func setTableData() {
        self.tableData = Array<TableSection>()
        tableData.append(TableSection(title: "", item: []))
        tableData[0].item.append(TableCell())
        var tableDataIndex = 1
        self.tableData.append(TableSection(title: "", item: []))
        let password = self.password!
        if let username = password.getUsername() {
            self.tableData[tableDataIndex].item.append(TableCell(title: "username", content: username))
        }
        self.tableData[tableDataIndex].item.append(TableCell(title: "password", content: password.password))
        
        // Show one time password
        if password.otpType == "totp", password.otpToken != nil {
            self.tableData.append(TableSection(title: "One time password (TOTP)", item: []))
            tableDataIndex += 1
            if let crtPassword = password.otpToken?.currentPassword {
                self.tableData[tableDataIndex].item.append(TableCell(title: "current", content: crtPassword))
            }
        }
        
        // Show additional information
        let filteredAdditionKeys = password.additionKeys.filter {
            $0.lowercased() != "username" &&
                $0.lowercased() != "password" &&
                (!$0.hasPrefix("unknown") || !Defaults[.isHideOTPOn]) &&
                (!Password.otpKeywords.contains($0) || !Defaults[.isHideOTPOn]) }
        
        if filteredAdditionKeys.count > 0 {
            self.tableData.append(TableSection(title: "additions", item: []))
            tableDataIndex += 1
            for additionKey in filteredAdditionKeys {
                self.tableData[tableDataIndex].item.append(TableCell(title: additionKey, content: password.additions[additionKey]!))
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "editPasswordSegue" {
            if let controller = segue.destination as? UINavigationController {
                if let editController = controller.viewControllers.first as? EditPasswordTableViewController {
                    editController.password = password
                }
            }
        }
    }
    
    func updatePasswordImage(url: String) {
        do {
            try FavIcon.downloadPreferred(url) { [weak self] result in
                switch result {
                case .success(let image):
                    let indexPath = IndexPath(row: 0, section: 0)
                    self?.passwordImage = image
                    self?.tableView.reloadRows(at: [indexPath], with: UITableViewRowAnimation.automatic)
                    let imageData = UIImageJPEGRepresentation(image, 1)
                    if let entity = self?.passwordEntity {
                        PasswordStore.shared.updateImage(passwordEntity: entity, image: imageData)
                    }
                case .failure(let error):
                    print(error)
                }
            }
        } catch {
            print(error)
        }
    }
    
    func tapMenu(recognizer: UITapGestureRecognizer)  {
        if recognizer.state == UIGestureRecognizerState.ended {
            let tapLocation = recognizer.location(in: self.tableView)
            if let tapIndexPath = self.tableView.indexPathForRow(at: tapLocation) {
                if let tappedCell = self.tableView.cellForRow(at: tapIndexPath) as? LabelTableViewCell {
                    tappedCell.becomeFirstResponder()
                    let menuController = UIMenuController.shared
                    let revealItem = UIMenuItem(title: "Reveal", action: #selector(LabelTableViewCell.revealPassword(_:)))
                    let concealItem = UIMenuItem(title: "Conceal", action: #selector(LabelTableViewCell.concealPassword(_:)))
                    let openURLItem = UIMenuItem(title: "Copy Password & Open Link", action: #selector(LabelTableViewCell.openLink(_:)))
                    menuController.menuItems = [revealItem, concealItem, openURLItem]
                    menuController.setTargetRect(tappedCell.contentLabel.frame, in: tappedCell.contentLabel.superview!)
                    menuController.setMenuVisible(true, animated: true)
                }
            }
        }
    }
    

    override func numberOfSections(in tableView: UITableView) -> Int {
        return tableData.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableData[section].item.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let sectionIndex = indexPath.section
        let rowIndex = indexPath.row
        
        if sectionIndex == 0 && rowIndex == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "passwordDetailTitleTableViewCell", for: indexPath) as! PasswordDetailTitleTableViewCell
            cell.passwordImageImageView.image = passwordImage ?? #imageLiteral(resourceName: "PasswordImagePlaceHolder")
            var passwordName = passwordEntity!.name!
            if passwordEntity!.synced == false {
                passwordName = "\(passwordName) ↻"
            }
            cell.nameLabel.text = passwordName
            cell.categoryLabel.text = passwordCategoryText
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "labelCell", for: indexPath) as! LabelTableViewCell
            let titleData = tableData[sectionIndex].item[rowIndex].title
            let contentData = tableData[sectionIndex].item[rowIndex].content
            cell.password = password
            cell.isPasswordCell = (titleData.lowercased() == "password" ? true : false)
            cell.isURLCell = (titleData.lowercased() == "url" ? true : false)
            cell.cellData = LabelTableViewCellData(title: titleData, content: contentData)
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return tableData[section].title
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == tableData.count - 1 {
            let view = UIView()
            let footerLabel = UILabel(frame: CGRect(x: 15, y: 15, width: tableView.frame.width, height: 60))
            footerLabel.numberOfLines = 0
            footerLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
            footerLabel.textColor = UIColor.gray
            let dateString = PasswordStore.shared.getLatestUpdateInfo(filename: (passwordEntity?.path)!)
            footerLabel.text = "Last Updated: \(dateString)"
            view.addSubview(footerLabel)
            return view
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
        if action == #selector(copy(_:)) {
            Utils.copyToPasteboard(textToCopy: tableData[indexPath.section].item[indexPath.row].content)
        }
    }
    
    override func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return action == #selector(UIResponderStandardEditActions.copy(_:))
    }
    
    override func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
        return true
    }

}
