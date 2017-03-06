//
//  LabelTableViewCell.swift
//  pass
//
//  Created by Mingshen Sun on 2/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import SVProgressHUD


struct LabelTableViewCellData {
    var title: String
    var content: String
}

class LabelTableViewCell: UITableViewCell {

    @IBOutlet weak var contentLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!

    var isPasswordCell = false
    var isURLCell = false
    var isReveal = false
    var isHOTPCell = false
    let passwordDots = "••••••••••••"
    
    weak var passwordTableView : PasswordDetailTableViewController?
    
    var cellData: LabelTableViewCellData? {
        didSet {
            titleLabel.text = cellData?.title ?? ""
            if isPasswordCell {
                if isReveal {
                    contentLabel.attributedText = Utils.attributedPassword(plainPassword: cellData?.content ?? "")
                } else {
                    contentLabel.text = passwordDots
                }
                contentLabel.font = UIFont(name: "Menlo", size: contentLabel.font.pointSize)
            } else if isHOTPCell {
                if isReveal {
                    contentLabel.text = cellData?.content ?? ""
                } else {
                    contentLabel.text = passwordDots
                }
            } else {
                contentLabel.text = cellData?.content
            }
        }
    }
    
    override var canBecomeFirstResponder: Bool {
        get {
            return true
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if isPasswordCell {
            if isReveal {
                return action == #selector(copy(_:)) || action == #selector(LabelTableViewCell.concealPassword(_:))
            } else {
                return action == #selector(copy(_:)) || action == #selector(LabelTableViewCell.revealPassword(_:))
            }
        }
        if isURLCell {
            return action == #selector(copy(_:)) || action == #selector(LabelTableViewCell.openLink(_:))
        }
        if isHOTPCell {
            if isReveal {
                return action == #selector(copy(_:)) || action == #selector(LabelTableViewCell.concealPassword(_:)) || action == #selector(LabelTableViewCell.nextPassword(_:))
            } else {
                return action == #selector(copy(_:)) || action == #selector(LabelTableViewCell.revealPassword(_:)) || action == #selector(LabelTableViewCell.nextPassword(_:))
            }
        }
        return action == #selector(copy(_:))
    }
    
    override func copy(_ sender: Any?) {
        Utils.copyToPasteboard(textToCopy: cellData?.content)
    }
        
    func revealPassword(_ sender: Any?) {
        if let plainPassword = cellData?.content {
            if isHOTPCell {
                contentLabel.text = plainPassword
            } else {
                contentLabel.attributedText = Utils.attributedPassword(plainPassword: plainPassword)
            }
        } else {
            contentLabel.text = ""
        }
        isReveal = true
    }
    
    func concealPassword(_ sender: Any?) {
        contentLabel.text = passwordDots
        isReveal = false
    }
    
    func nextPassword(_ sender: Any?) {
        guard let password = passwordTableView?.password,
            let passwordEntity = passwordTableView?.passwordEntity else {
                print("Cannot find password/passwordEntity of a cell")
                return;
        }
        
        // increase HOTP counter
        password.increaseHotpCounter()
        
        // only the HOTP password needs update
        if let plainPassword = password.otpToken?.currentPassword {
            cellData?.content = plainPassword
            // contentLabel will be updated automatically
        }
        
        // commit
        if password.changed {
            DispatchQueue.global(qos: .userInitiated).async {
                PasswordStore.shared.update(passwordEntity: passwordEntity, password: password, progressBlock: {_ in })
                DispatchQueue.main.async {
                    passwordEntity.synced = false
                    PasswordStore.shared.saveUpdated(passwordEntity: passwordEntity)
                    NotificationCenter.default.post(Notification(name: Notification.Name("passwordUpdated")))
                    // reload so that the "unsynced" symbol could be added
                    self.passwordTableView?.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: UITableViewRowAnimation.automatic)
                    SVProgressHUD.showSuccess(withStatus: "Password Copied\nCounter Updated")
                    SVProgressHUD.dismiss(withDelay: 1)
                }
            }
        }
    }
    
    func openLink(_ sender: Any?) {
        guard let password = passwordTableView?.password else {
            print("Cannot find password of a cell")
            return;
        }
        Utils.copyToPasteboard(textToCopy: password.password)
        UIApplication.shared.open(URL(string: cellData!.content)!, options: [:], completionHandler: nil)
    }
}
