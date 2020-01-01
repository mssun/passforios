//
//  PasswordDetailTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 2/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import FavIcon
import SVProgressHUD
import passKit

class PasswordDetailTableViewController: UITableViewController, UIGestureRecognizerDelegate {
    var passwordEntity: PasswordEntity?
    private var password: Password?
    private var passwordImage: UIImage?
    private var oneTimePasswordIndexPath : IndexPath?
    private var shouldPopCurrentView = false
    private let passwordStore = PasswordStore.shared
    private let keychain = AppKeychain.shared

    private lazy var editUIBarButtonItem: UIBarButtonItem = {
        let uiBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(pressEdit(_:)))
        return uiBarButtonItem
    }()

    private struct TableSection {
        var type: PasswordDetailTableViewControllerSectionType
        var header: String?
        var item: [AdditionField] = []

        init(type: PasswordDetailTableViewControllerSectionType, header: String? = nil) {
            self.type = type
            self.header = header
        }
    }

    private var tableData = [TableSection]()

    private enum PasswordDetailTableViewControllerSectionType {
        case name, main, addition, misc
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UINib(nibName: "LabelTableViewCell", bundle: nil), forCellReuseIdentifier: "labelCell")
        tableView.register(UINib(nibName: "PasswordDetailTitleTableViewCell", bundle: nil), forCellReuseIdentifier: "passwordDetailTitleTableViewCell")

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(PasswordDetailTableViewController.tapMenu(recognizer:)))
        tapGesture.cancelsTouchesInView = false
        tableView.addGestureRecognizer(tapGesture)
        tapGesture.delegate = self

        tableView.contentInset = UIEdgeInsets.init(top: -36, left: 0, bottom: 44, right: 0);
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 52

        editUIBarButtonItem.isEnabled = false
        navigationItem.rightBarButtonItem = editUIBarButtonItem
        if #available(iOS 11.0, *) {
            navigationItem.largeTitleDisplayMode = .never
        }

        if let imageData = passwordEntity?.getImage() {
            let image = UIImage(data: imageData as Data)
            passwordImage = image
        }
        self.decryptThenShowPassword()
        self.setupOneTimePasswordAutoRefresh()

        // pop the current view because this password might be "discarded"
        NotificationCenter.default.addObserver(self, selector: #selector(setShouldPopCurrentView), name: .passwordStoreChangeDiscarded, object: nil)

        // reset the data table if the disaply settings have been changed
        NotificationCenter.default.addObserver(self, selector: #selector(decryptThenShowPassword), name: .passwordDetailDisplaySettingChanged, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self.shouldPopCurrentView {
            let alert = UIAlertController(title: "Notice".localize(), message: "PreviousChangesDiscarded.".localize(), preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "Ok".localize(), style: UIAlertAction.Style.default, handler: {_ in
                _ = self.navigationController?.popViewController(animated: true)
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }

    private func requestPGPKeyPassphrase() -> String {
        let sem = DispatchSemaphore(value: 0)
        var passphrase = ""
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Passphrase".localize(), message: "FillInPgpPassphrase.".localize(), preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "Ok".localize(), style: UIAlertAction.Style.default, handler: {_ in
                passphrase = alert.textFields!.first!.text!
                sem.signal()
            }))
            alert.addTextField(configurationHandler: {(textField: UITextField!) in
                textField.text = self.keychain.get(for: Globals.pgpKeyPassphrase) ?? ""
                textField.isSecureTextEntry = true
            })
            self.present(alert, animated: true, completion: nil)
        }
        let _ = sem.wait(timeout: DispatchTime.distantFuture)
        if Defaults.isRememberPGPPassphraseOn {
            self.keychain.add(string: passphrase, for: Globals.pgpKeyPassphrase)
        }
        return passphrase
    }

    @objc private func decryptThenShowPassword() {
        guard let passwordEntity = passwordEntity else {
            Utils.alert(title: "CannotShowPassword".localize(), message: "PasswordDoesNotExist".localize(), controller: self, handler: {(UIAlertAction) -> Void in
                self.navigationController!.popViewController(animated: true)
            })
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            // decrypt password
            do {
                self.password = try self.passwordStore.decrypt(passwordEntity: passwordEntity, requestPGPKeyPassphrase: self.requestPGPKeyPassphrase)
            } catch {
                DispatchQueue.main.async {
                    // alert: cancel or try again
                    let alert = UIAlertController(title: "CannotShowPassword".localize(), message: error.localizedDescription, preferredStyle: UIAlertController.Style.alert)
                    alert.addAction(UIAlertAction(title: "Cancel".localize(), style: UIAlertAction.Style.default) { _ in
                        self.navigationController!.popViewController(animated: true)
                    })
                    alert.addAction(UIAlertAction(title: "TryAgain".localize(), style: UIAlertAction.Style.destructive) {_ in
                        self.decryptThenShowPassword()
                    })
                    self.present(alert, animated: true, completion: nil)
                }
                return
            }
            // display password
            self.showPassword()
        }
    }

    private func showPassword() {
        DispatchQueue.main.async { [weak self] in
            self?.setTableData()
            self?.tableView.reloadData()
            self?.editUIBarButtonItem.isEnabled = true
            if !Defaults.isHidePasswordImagesOn {
                if let urlString = self?.password?.urlString {
                    if self?.passwordEntity?.getImage() == nil {
                        self?.updatePasswordImage(urlString: urlString)
                    }
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
                    strongSelf.tableData[indexPath.section].item[indexPath.row] = title => otp
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
        if self.password!.changed != 0 {
            SVProgressHUD.show(withStatus: "Saving".localize())
            do {
                self.passwordEntity = try self.passwordStore.edit(passwordEntity: self.passwordEntity!, password: self.password!)
                self.setTableData()
                self.tableView.reloadData()
                SVProgressHUD.showSuccess(withStatus: "Success".localize())
                SVProgressHUD.dismiss(withDelay: 1)
            } catch {
                SVProgressHUD.showSuccess(withStatus: error.localizedDescription)
                SVProgressHUD.dismiss(withDelay: 1)
            }
        }
    }

    @IBAction private func deletePassword(segue: UIStoryboardSegue) {
        do {
            try passwordStore.delete(passwordEntity: passwordEntity!)
        } catch {
            Utils.alert(title: "Error".localize(), message: error.localizedDescription, controller: self, completion: nil)
        }
        let _ = navigationController?.popViewController(animated: true)
    }

    private func setTableData() {
        self.tableData = Array<TableSection>()

        // name section
        var section = TableSection(type: .name)
        section.item.append(AdditionField())
        tableData.append(section)

        // main section
        section = TableSection(type: .main)
        let password = self.password!
        if let username = password.username {
            section.item.append(Constants.USERNAME_KEYWORD => username)
        }
        if let login = password.login {
            section.item.append(Constants.LOGIN_KEYWORD => login)
        }
        section.item.append(Constants.PASSWORD_KEYWORD => password.password)
        tableData.append(section)


        // addition section

        // show one time password
        if password.otpType != .none {
            if let (title, otp) = self.password?.getOtpStrings() {
                section = TableSection(type: .addition, header: "OneTimePassword".localize())
                section.item.append(title => otp)
                tableData.append(section)
                oneTimePasswordIndexPath = IndexPath(row: 0, section: tableData.count - 1)
            }
        }

        // show additional information
        let filteredAdditionKeys = password.getFilteredAdditions()
        if filteredAdditionKeys.count > 0 {
            section = TableSection(type: .addition, header: "Additions".localize())
            section.item.append(contentsOf: filteredAdditionKeys)
            tableData.append(section)
        }

        // misc section
        section = TableSection(type: .misc)
        section.item.append(AdditionField(title: "ShowRaw".localize()))
        tableData.append(section)

    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "editPasswordSegue" {
            if let controller = segue.destination as? UINavigationController {
                if let editController = controller.viewControllers.first as? EditPasswordTableViewController {
                    editController.password = password
                }
            }
        } else if segue.identifier == "showRawPasswordSegue" {
            if let controller = segue.destination as? UINavigationController {
                if let controller = controller.viewControllers.first as? RawPasswordViewController {
                    controller.password = password
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

        try? FavIcon.downloadPreferred(newUrlString) { [weak self] result in
            if case let .success(image) = result {
                let indexPath = IndexPath(row: 0, section: 0)
                self?.passwordImage = image
                self?.tableView.reloadRows(at: [indexPath], with: UITableView.RowAnimation.automatic)
                let imageData = image.jpegData(compressionQuality: 1)
                if let entity = self?.passwordEntity {
                    self?.passwordStore.updateImage(passwordEntity: entity, image: imageData)
                }
            }
        }
    }

    @objc private func tapMenu(recognizer: UITapGestureRecognizer)  {
        if recognizer.state == UIGestureRecognizer.State.ended {
            let tapLocation = recognizer.location(in: self.tableView)
            if let tapIndexPath = self.tableView.indexPathForRow(at: tapLocation) {
                if let tappedCell = self.tableView.cellForRow(at: tapIndexPath) as? LabelTableViewCell {
                    tappedCell.becomeFirstResponder()
                    let menuController = UIMenuController.shared
                    let revealItem = UIMenuItem(title: "Reveal".localize(), action: #selector(LabelTableViewCell.revealPassword(_:)))
                    let concealItem = UIMenuItem(title: "Conceal".localize(), action: #selector(LabelTableViewCell.concealPassword(_:)))
                    let nextHOTPItem = UIMenuItem(title: "NextPassword".localize(), action: #selector(LabelTableViewCell.getNextHOTP(_:)))
                    let openURLItem = UIMenuItem(title: "CopyAndOpen".localize(), action: #selector(LabelTableViewCell.openLink(_:)))
                    menuController.menuItems = [revealItem, concealItem, nextHOTPItem, openURLItem]
                    menuController.setTargetRect(tappedCell.contentLabel.frame, in: tappedCell.contentLabel.superview!)
                    menuController.setMenuVisible(true, animated: true)
                }
            }
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view!.isKind(of: UIButton.classForCoder()) {
            return false
        }
        return true
    }

    @IBAction func back(segue:UIStoryboardSegue) {
    }

    func getNextHOTP() {
        guard password != nil, passwordEntity != nil, password?.otpType == .hotp else {
            DispatchQueue.main.async {
                Utils.alert(title: "Error".localize(), message: "GetNextPasswordOfNonHotp.".localize(), controller: self, completion: nil)
            }
            return;
        }

        // copy HOTP to pasteboard (will update counter)
        if let plainPassword = password!.getNextHotp() {
            SecurePasteboard.shared.copy(textToCopy: plainPassword)
        }

        // commit the change of HOTP counter
        if password!.changed != 0 {
            do {
                self.passwordEntity = try self.passwordStore.edit(passwordEntity: self.passwordEntity!, password: self.password!)
                SVProgressHUD.showSuccess(withStatus: "PasswordCopied".localize() | "CounterUpdated".localize())
                SVProgressHUD.dismiss(withDelay: 1)
            } catch {
                SVProgressHUD.showSuccess(withStatus: error.localizedDescription)
                SVProgressHUD.dismiss(withDelay: 1)
            }
        }
    }

    func openLink(to address: String?) {
        guard address != nil, let url = URL(string: formActualWebAddress(from: address!)) else {
            return DispatchQueue.main.async {
                Utils.alert(title: "Error".localize(), message: "CannotFindValidUrl".localize(), controller: self, completion: nil)
            }
        }
        SecurePasteboard.shared.copy(textToCopy: password?.password)
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    private func formActualWebAddress(from: String) -> String {
        let lowercased = from.lowercased()
        if !(lowercased.starts(with: "https://") || lowercased.starts(with: "http://")) {
            return "https://\(from)"
        }
        return from
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
            if !Defaults.isHidePasswordImagesOn {
                cell.labelCellConstraint.isActive = false
                cell.labelImageConstraint.isActive = true
                cell.passwordImageImageView.image = passwordImage ?? #imageLiteral(resourceName: "PasswordImagePlaceHolder")
                cell.passwordImageImageView.isHidden = false
            } else {
                cell.passwordImageImageView.image = nil
                cell.passwordImageImageView.isHidden = true
                cell.labelImageConstraint.isActive = false
                cell.labelCellConstraint.isActive = true
            }
            let passwordName = passwordEntity!.getName()
            if passwordEntity!.synced == false {
                cell.nameLabel.text = "\(passwordName) ↻"
            } else {
                cell.nameLabel.text = passwordName
            }
            cell.categoryLabel.text = passwordEntity!.getCategoryText()
            cell.selectionStyle = .none
            return cell
        case .main, .addition:
            let cell = tableView.dequeueReusableCell(withIdentifier: "labelCell", for: indexPath) as! LabelTableViewCell
            let titleData = tableDataItem.title
            let contentData = tableDataItem.content
            cell.delegatePasswordTableView = self
            cell.cellData = LabelTableViewCellData(title: titleData, content: contentData)
            cell.selectionStyle = .none
            return cell
        case .misc:
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.textLabel?.text = tableDataItem.title
            cell.selectionStyle = .default
            addHiddenFieldInformation(to: cell)
            return cell
        }
    }

    private func addHiddenFieldInformation(to cell: UITableViewCell) {
        guard password != nil, let detailTextLabel = cell.detailTextLabel else {
            return
        }

        var numberOfHiddenFields = 0
        numberOfHiddenFields += Defaults.isHideUnknownOn ? password!.numberOfUnknowns : 0
        numberOfHiddenFields += Defaults.isHideOTPOn ? password!.numberOfOtpRelated : 0
        guard numberOfHiddenFields > 0 else {
            return
        }

        detailTextLabel.textAlignment = .center
        detailTextLabel.textColor = .gray
        detailTextLabel.text = "HiddenFields(%d)".localize(numberOfHiddenFields)
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
            let dateString = self.passwordStore.getLatestUpdateInfo(filename: password!.url.path)
            footerLabel.text = "LastUpdated".localize(dateString)
            view.addSubview(footerLabel)
            return view
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
        if action == #selector(copy(_:)) {
            SecurePasteboard.shared.copy(textToCopy: tableData[indexPath.section].item[indexPath.row].content)
        }
    }

    override func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        let section = tableData[indexPath.section]
        switch(section.type) {
        case .main, .addition:
            return action == #selector(UIResponderStandardEditActions.copy(_:))
        default:
            return false
        }
    }

    override func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = tableData[indexPath.section]
        if section.type == .misc {
            if section.item[indexPath.row].title == "ShowRaw".localize() {
                performSegue(withIdentifier: "showRawPasswordSegue", sender: self)
            }
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
