//
//  PasswordDetailTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 2/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import FavIcon
import passKit
import SVProgressHUD
import UIKit

class PasswordDetailTableViewController: UITableViewController, UIGestureRecognizerDelegate {
    var passwordEntity: PasswordEntity?
    private var password: Password?
    private var passwordImage: UIImage?
    private var oneTimePasswordIndexPath: IndexPath?
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

        tableView.contentInset = UIEdgeInsets(top: -36, left: 0, bottom: 44, right: 0)
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
        decryptThenShowPassword()
        setupOneTimePasswordAutoRefresh()

        // pop the current view because this password might be "discarded"
        NotificationCenter.default.addObserver(self, selector: #selector(setShouldPopCurrentView), name: .passwordStoreChangeDiscarded, object: nil)

        // reset the data table if the disaply settings have been changed
        NotificationCenter.default.addObserver(self, selector: #selector(decryptThenShowPasswordSelector), name: .passwordDetailDisplaySettingChanged, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if shouldPopCurrentView {
            let alert = UIAlertController(title: "Notice".localize(), message: "PreviousChangesDiscarded.".localize(), preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction.okAndPopView(controller: self))
            present(alert, animated: true, completion: nil)
        }
    }

    @objc
    private func decryptThenShowPasswordSelector(_ sender: Any) {
        decryptThenShowPassword()
    }

    private func decryptThenShowPassword(keyID: String? = nil) {
        guard let passwordEntity = passwordEntity else {
            Utils.alert(title: "CannotShowPassword".localize(), message: "PasswordDoesNotExist".localize(), controller: self, completion: {
                self.navigationController!.popViewController(animated: true)
            })
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            // decrypt password
            do {
                let requestPGPKeyPassphrase = Utils.createRequestPGPKeyPassphraseHandler(controller: self)
                self.password = try self.passwordStore.decrypt(passwordEntity: passwordEntity, keyID: keyID, requestPGPKeyPassphrase: requestPGPKeyPassphrase)
                self.showPassword()
            } catch let AppError.pgpPrivateKeyNotFound(keyID: key) {
                DispatchQueue.main.async {
                    // alert: cancel or try again
                    let alert = UIAlertController(title: "CannotShowPassword".localize(), message: AppError.pgpPrivateKeyNotFound(keyID: key).localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction.cancelAndPopView(controller: self))
                    let selectKey = UIAlertAction.selectKey(controller: self) { action in
                        self.decryptThenShowPassword(keyID: action.title)
                    }
                    alert.addAction(selectKey)

                    self.present(alert, animated: true, completion: nil)
                }
            } catch {
                DispatchQueue.main.async {
                    // alert: cancel or try again
                    let alert = UIAlertController(title: "CannotShowPassword".localize(), message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction.cancelAndPopView(controller: self))
                    alert.addAction(
                        UIAlertAction(title: "TryAgain".localize(), style: .default) { _ in
                            self.decryptThenShowPassword()
                        }
                    )
                    self.present(alert, animated: true, completion: nil)
                }
            }
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
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
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

    @objc
    private func pressEdit(_: Any?) {
        performSegue(withIdentifier: "editPasswordSegue", sender: self)
    }

    @objc
    private func setShouldPopCurrentView() {
        shouldPopCurrentView = true
    }

    @IBAction
    private func cancelEditPassword(segue _: UIStoryboardSegue) {}

    @IBAction
    private func saveEditPassword(segue _: UIStoryboardSegue) {
        if password!.changed != 0 {
            saveEditPassword(password: password!)
        }
    }

    private func saveEditPassword(password: Password, keyID: String? = nil) {
        SVProgressHUD.show(withStatus: "Saving".localize())
        do {
            passwordEntity = try passwordStore.edit(passwordEntity: passwordEntity!, password: password, keyID: keyID)
            setTableData()
            tableView.reloadData()
            SVProgressHUD.showSuccess(withStatus: "Success".localize())
            SVProgressHUD.dismiss(withDelay: 1)
        } catch let AppError.pgpPublicKeyNotFound(keyID: key) {
            DispatchQueue.main.async {
                // alert: cancel or select keys
                SVProgressHUD.dismiss()
                let alert = UIAlertController(title: "Cannot Edit Password", message: AppError.pgpPublicKeyNotFound(keyID: key).localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction.cancelAndPopView(controller: self))
                let selectKey = UIAlertAction.selectKey(controller: self) { action in
                    self.saveEditPassword(password: password, keyID: action.title)
                }
                alert.addAction(selectKey)

                self.present(alert, animated: true, completion: nil)
            }
            return
        } catch {
            DispatchQueue.main.async {
                Utils.alert(title: "Error".localize(), message: error.localizedDescription, controller: self, completion: nil)
            }
        }
    }

    @IBAction
    private func deletePassword(segue _: UIStoryboardSegue) {
        do {
            try passwordStore.delete(passwordEntity: passwordEntity!)
        } catch {
            Utils.alert(title: "Error".localize(), message: error.localizedDescription, controller: self, completion: nil)
        }
        _ = navigationController?.popViewController(animated: true)
    }

    private func setTableData() {
        tableData = [TableSection]()

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
        if !filteredAdditionKeys.isEmpty {
            section = TableSection(type: .addition, header: "Additions".localize())
            section.item.append(contentsOf: filteredAdditionKeys)
            tableData.append(section)
        }

        // misc section
        section = TableSection(type: .misc)
        section.item.append(AdditionField(title: "ShowRaw".localize()))
        tableData.append(section)
    }

    override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
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
            newUrlString = urlString.replacingOccurrences(
                of: "http://",
                with: "https://",
                options: .caseInsensitive,
                range: urlString.range(of: "http://")
            )
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

    @objc
    private func tapMenu(recognizer: UITapGestureRecognizer) {
        if recognizer.state == UIGestureRecognizer.State.ended {
            let tapLocation = recognizer.location(in: tableView)
            if let tapIndexPath = tableView.indexPathForRow(at: tapLocation) {
                if let tappedCell = tableView.cellForRow(at: tapIndexPath) as? LabelTableViewCell {
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

    func gestureRecognizer(_: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view!.isKind(of: UIButton.classForCoder()) {
            return false
        }
        return true
    }

    @IBAction
    private func back(segue _: UIStoryboardSegue) {}

    func getNextHOTP() {
        guard password != nil, passwordEntity != nil, password?.otpType == .hotp else {
            DispatchQueue.main.async {
                Utils.alert(title: "Error".localize(), message: "GetNextPasswordOfNonHotp.".localize(), controller: self, completion: nil)
            }
            return
        }

        // copy HOTP to pasteboard (will update counter)
        if let plainPassword = password!.getNextHotp() {
            SecurePasteboard.shared.copy(textToCopy: plainPassword)
        }

        // commit the change of HOTP counter
        if password!.changed != 0 {
            do {
                passwordEntity = try passwordStore.edit(passwordEntity: passwordEntity!, password: password!)
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

    override func numberOfSections(in _: UITableView) -> Int {
        tableData.count
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        tableData[section].item.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let sectionIndex = indexPath.section
        let rowIndex = indexPath.row
        let tableDataItem = tableData[sectionIndex].item[rowIndex]
        switch tableData[sectionIndex].type {
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
        case .addition, .main:
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

    override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        tableData[section].header
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == tableData.count - 1 {
            let view = UIView()
            let footerLabel = UILabel(frame: CGRect(x: 15, y: 15, width: tableView.frame.width, height: 60))
            footerLabel.numberOfLines = 0
            footerLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
            footerLabel.textColor = UIColor.gray
            let dateString = passwordStore.getLatestUpdateInfo(filename: password!.url.path)
            footerLabel.text = "LastUpdated".localize(dateString)
            view.addSubview(footerLabel)
            return view
        }
        return nil
    }

    override func tableView(_: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender _: Any?) {
        if action == #selector(copy(_:)) {
            SecurePasteboard.shared.copy(textToCopy: tableData[indexPath.section].item[indexPath.row].content)
        }
    }

    override func tableView(_: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender _: Any?) -> Bool {
        let section = tableData[indexPath.section]
        switch section.type {
        case .addition, .main:
            return action == #selector(UIResponderStandardEditActions.copy(_:))
        default:
            return false
        }
    }

    override func tableView(_: UITableView, shouldShowMenuForRowAt _: IndexPath) -> Bool {
        true
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
