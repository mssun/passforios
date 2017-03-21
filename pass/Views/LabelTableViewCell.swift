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
    
    weak var delegatePasswordTableView : PasswordDetailTableViewController?
    
    var cellData: LabelTableViewCellData? {
        didSet {
            titleLabel.text = cellData?.title ?? ""
            if isPasswordCell {
                if isReveal {
                    contentLabel.attributedText = Utils.attributedPassword(plainPassword: cellData?.content ?? "")
                } else {
                    contentLabel.text = Globals.passwordDots
                }
                contentLabel.font = UIFont(name: Globals.passwordFonts, size: contentLabel.font.pointSize)
            } else if isHOTPCell {
                if isReveal {
                    contentLabel.text = cellData?.content ?? ""
                } else {
                    contentLabel.text = Globals.passwordDots
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
                return action == #selector(copy(_:)) || action == #selector(LabelTableViewCell.concealPassword(_:)) || action == #selector(LabelTableViewCell.getNextHOTP(_:))
            } else {
                return action == #selector(copy(_:)) || action == #selector(LabelTableViewCell.revealPassword(_:)) || action == #selector(LabelTableViewCell.getNextHOTP(_:))
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
        contentLabel.text = Globals.passwordDots
        isReveal = false
    }
    
    func openLink(_ sender: Any?) {
        // if isURLCell, passwordTableView should not be nil
        delegatePasswordTableView!.openLink()
    }
    
    func getNextHOTP(_ sender: Any?) {
        // if isHOTPCell, passwordTableView should not be nil
        delegatePasswordTableView!.getNextHOTP()
    }
}
