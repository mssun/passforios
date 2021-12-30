//
//  BasicStaticTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 9/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import MessageUI
import passKit
import SafariServices
import UIKit

enum CellDataStyle {
    case value1, defaultStyle
}

enum CellDataKey {
    case style, title, link, accessoryType, detailDisclosureAction, detailDisclosureData, detailText, action
}

class BasicStaticTableViewController: UITableViewController, MFMailComposeViewControllerDelegate {
    var tableData = [[[CellDataKey: Any]]]()
    var navigationItemTitle: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        if navigationItemTitle != nil {
            navigationItem.title = navigationItemTitle
        }
    }

    override func numberOfSections(in _: UITableView) -> Int {
        tableData.count
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        tableData[section].count
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellData = tableData[indexPath.section][indexPath.row]
        let cellDataStyle = cellData[CellDataKey.style] as? CellDataStyle
        var cell: UITableViewCell?

        switch cellDataStyle ?? .defaultStyle {
        case .value1:
            cell = UITableViewCell(style: .value1, reuseIdentifier: "value1 cell")
            cell?.selectionStyle = .none
        default:
            cell = UITableViewCell(style: .default, reuseIdentifier: "default cell")
        }

        if let detailText = cellData[CellDataKey.detailText] as? String {
            cell?.detailTextLabel?.text = detailText
        }
        if let accessoryType = cellData[CellDataKey.accessoryType] as? UITableViewCell.AccessoryType {
            cell?.accessoryType = accessoryType
        } else {
            cell?.accessoryType = .disclosureIndicator
            cell?.selectionStyle = .default
        }

        cell?.textLabel?.text = cellData[CellDataKey.title] as? String
        return cell ?? UITableViewCell()
    }

    override func tableView(_: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let cellData = tableData[indexPath.section][indexPath.row]
        let selector = cellData[CellDataKey.detailDisclosureAction] as? Selector
        perform(selector, with: cellData[CellDataKey.detailDisclosureData])
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let cellData = tableData[indexPath.section][indexPath.row]
        let cellDataAction = cellData[CellDataKey.action] as? String
        switch cellDataAction ?? "" {
        case "segue":
            let link = cellData[CellDataKey.link] as? String
            performSegue(withIdentifier: link!, sender: self)
        case "link":
            let link = cellData[CellDataKey.link] as! String
            let url = URL(string: link)!
            switch url.scheme! {
            case "mailto":
                let urlComponents = URLComponents(string: link)!
                let subject = urlComponents.queryItems![0].value ?? ""
                if MFMailComposeViewController.canSendMail() {
                    sendEmail(toRecipients: [urlComponents.path], subject: subject)
                } else {
                    let email = urlComponents.path
                    let alertTitle = "CannotOpenMail".localize()
                    let alertMessage = "CopiedEmail".localize(email)
                    Utils.copyToPasteboard(textToCopy: email)
                    Utils.alert(title: alertTitle, message: alertMessage, controller: self, completion: nil)
                }
            case "http", "https":
                let svc = SFSafariViewController(url: URL(string: link)!)
                present(svc, animated: true, completion: nil)
            default:
                break
            }
        default:
            break
        }
    }

    override func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    override func tableView(_: UITableView, estimatedHeightForRowAt _: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    func sendEmail(toRecipients recipients: [String], subject: String) {
        let mailVC = MFMailComposeViewController()
        mailVC.mailComposeDelegate = self
        mailVC.setToRecipients(recipients)
        mailVC.setSubject(subject)
        mailVC.setMessageBody("", isHTML: false)
        present(mailVC, animated: true, completion: nil)
    }

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith _: MFMailComposeResult, error _: Error?) {
        controller.dismiss(animated: true)
    }
}
