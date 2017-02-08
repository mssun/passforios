//
//  PasswordDetailTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 2/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit

class PasswordDetailTableViewController: UITableViewController, UIGestureRecognizerDelegate {
    var passwordEntity: PasswordEntity?
    var passwordCategoryEntities: [PasswordCategoryEntity]?
    var passwordCategoryText = ""
    var password = Password()

    struct TableCell {
        var title: String
        var content: String
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
        
        let passwordCategoryArray = passwordCategoryEntities?.map({ (value: PasswordCategoryEntity) -> String in
            value.category!
        })
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
        
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            do {
                self.password = try self.passwordEntity!.decrypt()!
            } catch {
                let alert = UIAlertController(title: "Cannot Show Password", message: error.localizedDescription, preferredStyle: UIAlertControllerStyle.alert)
                alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: {(UIAlertAction) -> Void in
                    self.navigationController!.popViewController(animated: true)
                }))
                self.present(alert, animated: true, completion: nil)
            }
            
            var tableDataIndex = 0
            self.tableData.append(TableSection(title: "", item: []))
            if self.password.username != "" {
                self.tableData[tableDataIndex].item.append(TableCell(title: "username", content: self.password.username))
            }
            self.tableData[tableDataIndex].item.append(TableCell(title: "password", content: self.password.password))
            
            if self.password.additions.count > 0 {
                self.tableData.append(TableSection(title: "additions", item: []))
                tableDataIndex += 1
                for addition in self.password.additions {
                    self.tableData[tableDataIndex].item.append(TableCell(title: addition.title, content: addition.content))
                }
            }
            DispatchQueue.main.async {
                self.tableView.reloadData()
                indicator.stopAnimating()
                indicatorLable.isHidden = true
            }
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
        return tableData.count + 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }
        return tableData[section - 1].item.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let sectionIndex = indexPath.section
        let rowIndex = indexPath.row
        
        if sectionIndex == 0 && rowIndex == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "passwordDetailTitleTableViewCell", for: indexPath) as! PasswordDetailTitleTableViewCell
            cell.passwordImageImageView.image = #imageLiteral(resourceName: "PasswordImagePlaceHolder")
            cell.nameLabel.text = passwordEntity?.name
            cell.categoryLabel.text = passwordCategoryText
            return cell

        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "labelCell", for: indexPath) as! LabelTableViewCell
            let titleData = tableData[sectionIndex - 1].item[rowIndex].title
            let contentData = tableData[sectionIndex - 1].item[rowIndex].content
            cell.password = password
            cell.isPasswordCell = (titleData.lowercased() == "password" ? true : false)
            cell.isURLCell = (titleData.lowercased() == "url" ? true : false)
            cell.cellData = LabelTableViewCellData(title: titleData, content: contentData)
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return nil
        }
        return tableData[section - 1].title
    }
    
    override func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
        if action == #selector(copy(_:)) {
            UIPasteboard.general.string = tableData[indexPath.section].item[indexPath.row].content
        }
    }
    
    override func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return action == #selector(UIResponderStandardEditActions.copy(_:))
    }
    
    override func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
        return true
    }

}
