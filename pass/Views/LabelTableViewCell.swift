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
    
    var passwordDisplayButton: UIButton?
    var buttons: UIView?
    
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
                contentLabel.font = UIFont(name: Globals.passwordFonts, size: contentLabel.font.pointSize)
            } else {
                contentLabel.text = cellData?.content
            }
            updateButtons()
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
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if buttons != nil {
            self.accessoryView = buttons
        }
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
        passwordDisplayButton?.setImage(#imageLiteral(resourceName: "Invisible"), for: .normal)
    }
    
    func concealPassword(_ sender: Any?) {
        contentLabel.text = Globals.passwordDots
        isReveal = false
        passwordDisplayButton?.setImage(#imageLiteral(resourceName: "Visible"), for: .normal)
    }
    
    func reversePasswordDisplay(_ sender: Any?) {
        if isReveal {
            // conceal
            concealPassword(sender)
        } else {
            // reveal
            revealPassword(sender)
        }
    }

    
    func openLink(_ sender: Any?) {
        // if isURLCell, passwordTableView should not be nil
        delegatePasswordTableView!.openLink()
    }
    
    func getNextHOTP(_ sender: Any?) {
        // if isHOTPCell, passwordTableView should not be nil
        delegatePasswordTableView!.getNextHOTP()
    }
    
    func updateButtons() {
        passwordDisplayButton = nil
        buttons = nil
        
        // total width and height of a button
        let height = min(self.bounds.height, 36.0)
        let width = max(height * 0.8, Globals.tableCellButtonSize)
        
        // margins (between button boundary and icon)
        let marginY = max((height - Globals.tableCellButtonSize) / 2, 0.0)
        let marginX = max((width - Globals.tableCellButtonSize) / 2, 0.0)
        
        if isPasswordCell {
            // password button
            passwordDisplayButton = UIButton(type: .system)
            passwordDisplayButton!.frame = CGRect(x: 0, y: 0, width: width, height: height)
            passwordDisplayButton!.setImage(#imageLiteral(resourceName: "Visible"), for: .normal)
            passwordDisplayButton!.imageView?.contentMode = .scaleAspectFit
            passwordDisplayButton!.contentEdgeInsets = UIEdgeInsetsMake(marginY, marginX, marginY, marginX)
            passwordDisplayButton!.addTarget(self, action: #selector(reversePasswordDisplay), for: UIControlEvents.touchUpInside)
            buttons = passwordDisplayButton
        } else if isHOTPCell {
            // hotp button
            let nextButton = UIButton(type: .system)
            nextButton.frame = CGRect(x: 0, y: 0, width: width, height: height)
            nextButton.setImage(#imageLiteral(resourceName: "Refresh"), for: .normal)
            nextButton.imageView?.contentMode = .scaleAspectFit
            nextButton.contentEdgeInsets = UIEdgeInsetsMake(marginY, marginX, marginY, marginX)
            nextButton.addTarget(self, action: #selector(getNextHOTP), for: UIControlEvents.touchUpInside)
            
            // password button
            passwordDisplayButton = UIButton(type: .system)
            passwordDisplayButton!.frame = CGRect(x: width, y: 0, width: width, height: height)

            passwordDisplayButton!.setImage(#imageLiteral(resourceName: "Visible"), for: .normal)
            passwordDisplayButton!.imageView?.contentMode = .scaleAspectFit
            passwordDisplayButton!.contentEdgeInsets = UIEdgeInsetsMake(marginY, marginX, marginY, marginX)
            passwordDisplayButton!.addTarget(self, action: #selector(reversePasswordDisplay), for: UIControlEvents.touchUpInside)
            
            buttons = UIView()
            buttons!.frame = CGRect(x: 0, y: 0, width: width * 2, height: height)
            buttons!.addSubview(nextButton)
            buttons!.addSubview(passwordDisplayButton!)
        }
    }
}
