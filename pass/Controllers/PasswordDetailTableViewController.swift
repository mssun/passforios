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
    var oneTimePasswordIndexPath : IndexPath?
    var shouldPopCurrentView = false
    let passwordStore = PasswordStore.shared
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UINib(nibName: "LabelTableViewCell", bundle: nil), forCellReuseIdentifier: "labelCell")
        tableView.register(UINib(nibName: "PasswordDetailTitleTableViewCell", bundle: nil), forCellReuseIdentifier: "passwordDetailTitleTableViewCell")
        
        passwordCategoryText = passwordEntity!.getCategoryText()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(PasswordDetailTableViewController.tapMenu(recognizer:)))
        tableView.addGestureRecognizer(tapGesture)
        tapGesture.delegate = self
        
        tableView.contentInset = UIEdgeInsetsMake(-36, 0, 0, 0);
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
        
        self.setupUpdateOneTimePassword()
        self.addNotificationObservers()

    }
    
    func decryptThenShowPassword(passphrase: String) {
        if Defaults[.isRememberPassphraseOn] {
            self.passwordStore.pgpKeyPassphrase = passphrase
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
        editUIBarButtonItem.isEnabled = true
        if let urlString = password.getURLString() {
            if self.passwordEntity?.image == nil{
                self.updatePasswordImage(urlString: urlString)
            }
        }
    }
    
    func setupUpdateOneTimePassword() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
            [weak self] timer in
            // bail out of the timer code if the object has been freed
            guard let strongSelf = self,
                let token = strongSelf.password?.otpToken,
                let indexPath = strongSelf.oneTimePasswordIndexPath,
                let cell = strongSelf.tableView.cellForRow(at: indexPath) as? LabelTableViewCell else {
                    return
            }
            switch token.generator.factor {
            case .timer:
                // totp
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
    
    func pressEdit(_ sender: Any?) {
        performSegue(withIdentifier: "editPasswordSegue", sender: self)
    }
    
    @IBAction func cancelEditPassword(segue: UIStoryboardSegue) {
    
    }
    
    @IBAction func saveEditPassword(segue: UIStoryboardSegue) {
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
    
    @IBAction func deletePassword(segue: UIStoryboardSegue) {
        print("delete")
        passwordStore.delete(passwordEntity: passwordEntity!)
        navigationController?.popViewController(animated: true)
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
        
        // show one time password
        if let token = password.otpToken {
            switch token.generator.factor {
            case .counter(_):
                // counter-based one time password
                self.tableData.append(TableSection(title: "One time password", item: []))
                tableDataIndex += 1
                oneTimePasswordIndexPath = IndexPath(row: 0, section: tableDataIndex)
                if let crtPassword = password.otpToken?.currentPassword {
                    self.tableData[tableDataIndex].item.append(TableCell(title: "HMAC-based", content: crtPassword))
                }
            case .timer(let period):
                // time-based one time password
                self.tableData.append(TableSection(title: "One time password", item: []))
                tableDataIndex += 1
                oneTimePasswordIndexPath = IndexPath(row: 0, section: tableDataIndex)
                if let crtPassword = password.otpToken?.currentPassword {
                    let timeSinceEpoch = Date().timeIntervalSince1970
                    let validTime = Int(period - timeSinceEpoch.truncatingRemainder(dividingBy: period))
                    self.tableData[tableDataIndex].item.append(TableCell(title: "time-based (expiring in \(validTime)s)", content: crtPassword))
                }
            }
        }
        
        // show additional information
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
    
    func updatePasswordImage(urlString: String) {
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
    
    func tapMenu(recognizer: UITapGestureRecognizer)  {
        if recognizer.state == UIGestureRecognizerState.ended {
            let tapLocation = recognizer.location(in: self.tableView)
            if let tapIndexPath = self.tableView.indexPathForRow(at: tapLocation) {
                if let tappedCell = self.tableView.cellForRow(at: tapIndexPath) as? LabelTableViewCell {
                    tappedCell.becomeFirstResponder()
                    let menuController = UIMenuController.shared
                    let revealItem = UIMenuItem(title: "Reveal", action: #selector(LabelTableViewCell.revealPassword(_:)))
                    let concealItem = UIMenuItem(title: "Conceal", action: #selector(LabelTableViewCell.concealPassword(_:)))
                    let nextPasswordItem = UIMenuItem(title: "Next Password", action: #selector(LabelTableViewCell.nextPassword(_:)))
                    let openURLItem = UIMenuItem(title: "Copy Password & Open Link", action: #selector(LabelTableViewCell.openLink(_:)))
                    menuController.menuItems = [revealItem, concealItem, nextPasswordItem, openURLItem]
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
            cell.passwordTableView = self
            cell.isPasswordCell = (titleData.lowercased() == "password" ? true : false)
            cell.isURLCell = (titleData.lowercased() == "url" ? true : false)
            cell.isHOTPCell = (titleData == "HMAC-based" ? true : false)
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

    private func addNotificationObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(setShouldPopCurrentView), name: .passwordStoreChangeDiscarded, object: nil)
    }
    
    func setShouldPopCurrentView() {
        self.shouldPopCurrentView = true
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
}
