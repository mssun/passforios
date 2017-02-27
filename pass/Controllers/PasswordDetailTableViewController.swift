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
    var passwordCategoryEntities: [PasswordCategoryEntity]?
    var passwordCategoryText = ""
    var password: Password?
    var passwordImage: UIImage?

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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UINib(nibName: "LabelTableViewCell", bundle: nil), forCellReuseIdentifier: "labelCell")
        tableView.register(UINib(nibName: "PasswordDetailTitleTableViewCell", bundle: nil), forCellReuseIdentifier: "passwordDetailTitleTableViewCell")
        
        let passwordCategoryArray = passwordCategoryEntities?.map { $0.category! }
        passwordCategoryText = (passwordCategoryArray?.joined(separator: " > "))!
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(PasswordDetailTableViewController.tapMenu(recognizer:)))
        tableView.addGestureRecognizer(tapGesture)
        tapGesture.delegate = self
        
        tableView.contentInset = UIEdgeInsetsMake(-36, 0, 0, 0);
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 52
        let indicatorLable = UILabel(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 21))
        indicatorLable.center = CGPoint(x: view.frame.size.width / 2, y: view.frame.size.height * 0.382 + 22)
        indicatorLable.backgroundColor = UIColor.clear
        indicatorLable.textColor = UIColor.gray
        indicatorLable.text = "decrypting password"
        indicatorLable.textAlignment = .center
        indicatorLable.font = UIFont.preferredFont(forTextStyle: .footnote)
        let indicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        indicator.center = CGPoint(x: view.frame.size.width / 2, y: view.frame.size.height * 0.382)
        indicator.startAnimating()
        tableView.addSubview(indicator)
        tableView.addSubview(indicatorLable)
        let editUIBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(pressEdit(_:)))
        editUIBarButtonItem.isEnabled = false
        navigationItem.rightBarButtonItem = editUIBarButtonItem
        
        if let imageData = passwordEntity?.image {
            let image = UIImage(data: imageData as Data)
            passwordImage = image
        }
        
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                self.password = try self.passwordEntity!.decrypt()!
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
            self.setTableData()
            DispatchQueue.main.async { [weak self] in
                self?.tableView.reloadData()
                indicator.stopAnimating()
                indicatorLable.isHidden = true
                editUIBarButtonItem.isEnabled = true
                if let url = password.getURL() {
                    if self?.passwordEntity?.image == nil{
                        self?.updatePasswordImage(url: url)
                    }
                }
            }
        }
    }
    
    func pressEdit(_ sender: Any?) {
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
        if password.additions.count > 0 {
            self.tableData.append(TableSection(title: "additions", item: []))
            tableDataIndex += 1
            for additionKey in password.additionKeys {
                if (!additionKey.hasPrefix("unknown") || !Defaults[.isHideUnknownOn]) &&
                    additionKey.lowercased() != "username" &&
                    additionKey.lowercased() != "password" {
                    self.tableData[tableDataIndex].item.append(TableCell(title: additionKey, content: password.additions[additionKey]!))

                }
                
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
            let footerLabel = UILabel(frame: CGRect(x: 8, y: 15, width: tableView.frame.width, height: 60))
            footerLabel.numberOfLines = 0
            footerLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
            footerLabel.textColor = UIColor.lightGray
            let dateString = DateFormatter.localizedString(from: passwordEntity?.commitDate as! Date, dateStyle: DateFormatter.Style.long, timeStyle: DateFormatter.Style.long)
            footerLabel.text = "Latest commit: \(dateString)"
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
