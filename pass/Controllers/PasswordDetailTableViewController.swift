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
    private var password: Password?
    private var passwordCategoryText = ""
    private var passwordImage: UIImage?
    private var oneTimePasswordIndexPath : IndexPath?
    private var shouldPopCurrentView = false
    private let passwordStore = PasswordStore.shared
    
    private let indicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        indicator.center = CGPoint(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height * 0.382)
        return indicator
    }()
    
    private lazy var editUIBarButtonItem: UIBarButtonItem = {
        let uiBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(pressEdit(_:)))
        return uiBarButtonItem
    }()

    private struct TableCell {
        var title: String
        var content: String
        init() {
            title = ""
            content = ""
        }
        
        init(title: String) {
            self.title = title
            self.content = ""
        }
        
        init(title: String, content: String) {
            self.title = title
            self.content = content
        }
    }
    
    private struct TableSection {
        var type: PasswordDetailTableViewControllerSectionType
        var header: String?
        var item: Array<TableCell>
        init(type: PasswordDetailTableViewControllerSectionType) {
            self.type = type
            header = nil
            item = [TableCell]()
        }
        
        init(type: PasswordDetailTableViewControllerSectionType, header: String) {
            self.init(type: type)
            self.header = header
        }
    }
    
    private var tableData = Array<TableSection>()
    
    private enum PasswordDetailTableViewControllerSectionType {
        case name, main, addition, misc
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UINib(nibName: "LabelTableViewCell", bundle: nil), forCellReuseIdentifier: "labelCell")
        tableView.register(UINib(nibName: "PasswordDetailTitleTableViewCell", bundle: nil), forCellReuseIdentifier: "passwordDetailTitleTableViewCell")
        
        passwordCategoryText = passwordEntity!.getCategoryText()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(PasswordDetailTableViewController.tapMenu(recognizer:)))
        tableView.addGestureRecognizer(tapGesture)
        tapGesture.delegate = self
        
        tableView.contentInset = UIEdgeInsetsMake(-36, 0, 44, 0);
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 52
        
        indicator.startAnimating()
        tableView.addSubview(indicator)
        editUIBarButtonItem.isEnabled = false
        navigationItem.rightBarButtonItem = editUIBarButtonItem
        
        if let imageData = passwordEntity?.image {
            let image = UIImage(data: imageData as Data)
            passwordImage = image
        }
        
        var passphrase = ""
        if Defaults[.isRememberPassphraseOn] && self.passwordStore.pgpKeyPassphrase != nil {
            passphrase = self.passwordStore.pgpKeyPassphrase!
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
        
        self.setupOneTimePasswordAutoRefresh()
        
        // pop the current view because this password might be "discarded"
        NotificationCenter.default.addObserver(self, selector: #selector(setShouldPopCurrentView), name: .passwordStoreChangeDiscarded, object: nil)
        
        // reset the data table if some password (maybe another one) has been updated
        NotificationCenter.default.addObserver(self, selector: #selector(showPassword), name: .passwordStoreUpdated, object: nil)
        
        // reset the data table if the disaply settings have been changed
        NotificationCenter.default.addObserver(self, selector: #selector(showPassword), name: .passwordDetailDisplaySettingChanged, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self.shouldPopCurrentView {
            let alert = UIAlertController(title: "Notice", message: "All previous local changes have been discarded. Your current Password Store will be shown.", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {_ in
                _ = self.navigationController?.popViewController(animated: true)
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func decryptThenShowPassword(passphrase: String) {
        if Defaults[.isRememberPassphraseOn] {
            self.passwordStore.pgpKeyPassphrase = passphrase
        }
        DispatchQueue.global(qos: .userInitiated).async {
            // decrypt password
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
            // display password
            self.showPassword()
        }
    }
    
    @objc private func showPassword() {
        DispatchQueue.main.async { [weak self] in
            self?.indicator.stopAnimating()
            self?.setTableData()
            UIView.performWithoutAnimation {
                self?.tableView.reloadData()
                // add layoutIfNeeded solves the "flickering problem" during refresh
                self?.tableView.layoutIfNeeded()
            }
            self?.editUIBarButtonItem.isEnabled = true
            if let urlString = self?.password?.getURLString() {
                if self?.passwordEntity?.image == nil {
                    self?.updatePasswordImage(urlString: urlString)
                }
            }
        }
    }
    
    private func setupOneTimePasswordAutoRefresh() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
            [weak self] timer in
            // bail out of the timer code if the object has been freed
            guard let strongSelf = self,
                let otpType = strongSelf.password?.otpType,
                otpType != .none,
                let indexPath = strongSelf.oneTimePasswordIndexPath,
                let cell = strongSelf.tableView.cellForRow(at: indexPath) as? LabelTableViewCell else {
                    return
            }
            switch otpType {
            case .totp:
                if let (title, otp) = strongSelf.password?.getOtpStrings() {
                    strongSelf.tableData[indexPath.section].item[indexPath.row].title = title
                    strongSelf.tableData[indexPath.section].item[indexPath.row].content = otp
                    cell.cellData?.title = title
                    cell.cellData?.content = otp
                }
            default:
                break
            }
        }
    }
    
    @objc private func pressEdit(_ sender: Any?) {
        performSegue(withIdentifier: "editPasswordSegue", sender: self)
    }
    
    @objc private func setShouldPopCurrentView() {
        self.shouldPopCurrentView = true
    }
    
    @IBAction private func cancelEditPassword(segue: UIStoryboardSegue) {
    
    }
    
    @IBAction private func saveEditPassword(segue: UIStoryboardSegue) {
        if self.password!.changed {
            SVProgressHUD.show(withStatus: "Saving")
            DispatchQueue.global(qos: .userInitiated).async {
                self.passwordStore.update(passwordEntity: self.passwordEntity!, password: self.password!, progressBlock: { progress in
                    DispatchQueue.main.async {
                        SVProgressHUD.showProgress(progress, status: "Encrypting")
                    }
                })
                DispatchQueue.main.async {
                    self.passwordEntity!.synced = false
                    self.passwordStore.saveUpdated(passwordEntity: self.passwordEntity!)
                    self.setTableData()
                    self.tableView.reloadData()
                    SVProgressHUD.showSuccess(withStatus: "Success")
                    SVProgressHUD.dismiss(withDelay: 1)
                }
            }
        }
    }
    
    @IBAction private func deletePassword(segue: UIStoryboardSegue) {
        print("delete")
        passwordStore.delete(passwordEntity: passwordEntity!)
        let _ = navigationController?.popViewController(animated: true)
    }

    private func setTableData() {
        self.tableData = Array<TableSection>()
        
        // name section
        var section = TableSection(type: .name)
        section.item.append(TableCell())
        tableData.append(section)

        // main section
        section = TableSection(type: .main)
        let password = self.password!
        if let username = password.getUsername() {
            section.item.append(TableCell(title: "username", content: username))
        }
        section.item.append(TableCell(title: "password", content: password.password))
        tableData.append(section)

        
        // addition section
        
        // show one time password
        if password.otpType != .none {
            if let (title, otp) = self.password?.getOtpStrings() {
                section = TableSection(type: .addition, header: "One Time Password")
                section.item.append(TableCell(title: title, content: otp))
                tableData.append(section)
                oneTimePasswordIndexPath = IndexPath(row: 0, section: tableData.count)
            }
        }
        
        // show additional information
        let filteredAdditionKeys = password.additionKeys.filter {
            $0.lowercased() != "username" &&
                $0.lowercased() != "password" &&
                (!$0.hasPrefix("unknown") || !Defaults[.isHideUnknownOn]) &&
                (!Password.otpKeywords.contains($0) || !Defaults[.isHideOTPOn]) }
        
        if filteredAdditionKeys.count > 0 {
            section = TableSection(type: .addition, header: "additions")
            for additionKey in filteredAdditionKeys {
                section.item.append(TableCell(title: additionKey, content: password.additions[additionKey]!))
            }
            tableData.append(section)
        }
        
        // misc section
        section = TableSection(type: .misc)
        section.item.append(TableCell(title: "Show Raw"))
        tableData.append(section)
        
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
    
    private func updatePasswordImage(urlString: String) {
        var newUrlString = urlString
        if urlString.lowercased().hasPrefix("http://") {
            // try to replace http url to https url
            newUrlString = urlString.replacingOccurrences(of: "http://",
                                                       with: "https://",
                                                       options: .caseInsensitive,
                                                       range: urlString.range(of: "http://"))
        } else if urlString.lowercased().hasPrefix("https://") {
            // do nothing here
        } else {
            // if a url does not start with http or https, try to add https
            newUrlString = "https://\(urlString)"
        }
        
        guard let url = URL(string: newUrlString) else {
            return
        }
        
        do {
            try FavIcon.downloadPreferred(url) { [weak self] result in
                switch result {
                case .success(let image):
                    let indexPath = IndexPath(row: 0, section: 0)
                    self?.passwordImage = image
                    self?.tableView.reloadRows(at: [indexPath], with: UITableViewRowAnimation.automatic)
                    let imageData = UIImageJPEGRepresentation(image, 1)
                    if let entity = self?.passwordEntity {
                        self?.passwordStore.updateImage(passwordEntity: entity, image: imageData)
                    }
                case .failure(let error):
                    print(error)
                }
            }
        } catch {
            print(error)
        }
    }
    
    @objc private func tapMenu(recognizer: UITapGestureRecognizer)  {
        if recognizer.state == UIGestureRecognizerState.ended {
            let tapLocation = recognizer.location(in: self.tableView)
            if let tapIndexPath = self.tableView.indexPathForRow(at: tapLocation) {
                if let tappedCell = self.tableView.cellForRow(at: tapIndexPath) as? LabelTableViewCell {
                    tappedCell.becomeFirstResponder()
                    let menuController = UIMenuController.shared
                    let revealItem = UIMenuItem(title: "Reveal", action: #selector(LabelTableViewCell.revealPassword(_:)))
                    let concealItem = UIMenuItem(title: "Conceal", action: #selector(LabelTableViewCell.concealPassword(_:)))
                    let nextHOTPItem = UIMenuItem(title: "Next Password", action: #selector(LabelTableViewCell.getNextHOTP(_:)))
                    let openURLItem = UIMenuItem(title: "Copy Password & Open Link", action: #selector(LabelTableViewCell.openLink(_:)))
                    menuController.menuItems = [revealItem, concealItem, nextHOTPItem, openURLItem]
                    menuController.setTargetRect(tappedCell.contentLabel.frame, in: tappedCell.contentLabel.superview!)
                    menuController.setMenuVisible(true, animated: true)
                }
            }
        }
    }
    
    func getNextHOTP() {
        guard password != nil, passwordEntity != nil, password?.otpType == .hotp else {
            DispatchQueue.main.async {
                Utils.alert(title: "Error", message: "Get next password of a non-HOTP entry.", controller: self, completion: nil)
            }
            return;
        }
        
        // increase HOTP counter
        password!.increaseHotpCounter()
        
        // copy HOTP to pasteboard
        if let plainPassword = password!.getOtp() {
            Utils.copyToPasteboard(textToCopy: plainPassword)
        }
        
        // commit the change of HOTP counter
        if password!.changed {
            DispatchQueue.global(qos: .userInitiated).async {
                self.passwordStore.update(passwordEntity: self.passwordEntity!, password: self.password!, progressBlock: {_ in })
                DispatchQueue.main.async {
                    self.passwordEntity!.synced = false
                    self.passwordStore.saveUpdated(passwordEntity: self.passwordEntity!)
                    SVProgressHUD.showSuccess(withStatus: "Password Copied\nCounter Updated")
                    SVProgressHUD.dismiss(withDelay: 1)
                }
            }
        }
    }
    
    func openLink() {
        guard let urlString = self.password?.getURLString(), let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                Utils.alert(title: "Error", message: "Cannot find a valid URL", controller: self, completion: nil)
            }
            return;
        }
        Utils.copyToPasteboard(textToCopy: password?.password)
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
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
        let tableDataItem = tableData[sectionIndex].item[rowIndex]
        switch(tableData[sectionIndex].type) {
        case .name:
            let cell = tableView.dequeueReusableCell(withIdentifier: "passwordDetailTitleTableViewCell", for: indexPath) as! PasswordDetailTitleTableViewCell
            cell.passwordImageImageView.image = passwordImage ?? #imageLiteral(resourceName: "PasswordImagePlaceHolder")
            var passwordName = passwordEntity!.name!
            if passwordEntity!.synced == false {
                passwordName = "\(passwordName) ↻"
            }
            cell.nameLabel.text = passwordName
            cell.categoryLabel.text = passwordCategoryText
            return cell
        case .main, .addition:
            let cell = tableView.dequeueReusableCell(withIdentifier: "labelCell", for: indexPath) as! LabelTableViewCell
            let titleData = tableDataItem.title
            let contentData = tableDataItem.content
            cell.delegatePasswordTableView = self
            cell.isPasswordCell = (titleData.lowercased() == "password" ? true : false)
            cell.isURLCell = (titleData.lowercased() == "url" ? true : false)
            cell.isHOTPCell = (titleData == "HMAC-based" ? true : false)
            cell.cellData = LabelTableViewCellData(title: titleData, content: contentData)
            return cell
        case .misc:
            let cell = UITableViewCell()
            cell.textLabel?.text = tableDataItem.title
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return tableData[section].header
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == tableData.count - 1 {
            let view = UIView()
            let footerLabel = UILabel(frame: CGRect(x: 15, y: 15, width: tableView.frame.width, height: 60))
            footerLabel.numberOfLines = 0
            footerLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
            footerLabel.textColor = UIColor.gray
            let dateString = self.passwordStore.getLatestUpdateInfo(filename: (passwordEntity?.path)!)
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
