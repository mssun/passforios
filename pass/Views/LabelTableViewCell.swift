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
    
    private enum CellType {
        case password, URL, HOTP, other
    }

    private var type = CellType.other
    private var isReveal = false
    
    weak var delegatePasswordTableView : PasswordDetailTableViewController?
    
    private var passwordDisplayButton: UIButton?
    private var buttons: UIView?
    
    var cellData: LabelTableViewCellData? {
        didSet {
            guard let title = cellData?.title, let content = cellData?.content else {
                type = .other
                return
            }
            titleLabel.text = title
            switch title.lowercased() {
            case "password":
                type = .password
                if isReveal {
                    contentLabel.attributedText = Utils.attributedPassword(plainPassword: content)
                } else {
                    if content == "" {
                        contentLabel.text = ""
                    } else {
                        contentLabel.text = Globals.passwordDots
                    }
                }
                contentLabel.font = UIFont(name: Globals.passwordFonts, size: contentLabel.font.pointSize)
            case "hmac-based":
                type = .HOTP
                if isReveal {
                    contentLabel.text = content
                } else {
                    contentLabel.text = Globals.oneTimePasswordDots
                }
                contentLabel.font = UIFont(name: Globals.passwordFonts, size: contentLabel.font.pointSize)
            case "url":
                type = .URL
                contentLabel.text = content
            default:
                type = .other
                contentLabel.text = content
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
        switch type {
        case .password:
            if isReveal {
                return action == #selector(copy(_:)) || action == #selector(concealPassword(_:))
            } else {
                return action == #selector(copy(_:)) || action == #selector(revealPassword(_:))
            }
        case .URL:
            return action == #selector(copy(_:)) || action == #selector(openLink(_:))
        case .HOTP:
            if isReveal {
                return action == #selector(copy(_:)) || action == #selector(concealPassword(_:)) || action == #selector(getNextHOTP(_:))
            } else {
                return action == #selector(copy(_:)) || action == #selector(revealPassword(_:)) || action == #selector(getNextHOTP(_:))
            }
        default:
            return action == #selector(copy(_:))
        }
    }

    override func copy(_ sender: Any?) {
        Utils.copyToPasteboard(textToCopy: cellData?.content)
    }
        
    func revealPassword(_ sender: Any?) {
        let plainPassword = cellData?.content ?? ""
        if type == .password {
            contentLabel.attributedText = Utils.attributedPassword(plainPassword: plainPassword)
        } else {
            contentLabel.text = plainPassword
        }
        isReveal = true
        passwordDisplayButton?.setImage(#imageLiteral(resourceName: "Invisible"), for: .normal)
    }
    
    func concealPassword(_ sender: Any?) {
        if type == .password {
            if cellData?.content.isEmpty == false {
                contentLabel.text = Globals.passwordDots
            } else {
                contentLabel.text = ""
            }
        } else {
            contentLabel.text = Globals.oneTimePasswordDots
        }
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
    
    private func updateButtons() {
        // total width and height of a button
        let height = min(self.bounds.height, 36.0)
        let width = max(height * 0.8, Globals.tableCellButtonSize)
        
        // margins (between button boundary and icon)
        let marginY = max((height - Globals.tableCellButtonSize) / 2, 0.0)
        let marginX = max((width - Globals.tableCellButtonSize) / 2, 0.0)
        
        switch type {
        case .password:
            if let content = cellData?.content, content != "" {
                // password button
                passwordDisplayButton = UIButton(type: .system)
                passwordDisplayButton!.frame = CGRect(x: 0, y: 0, width: width, height: height)
                passwordDisplayButton!.setImage(#imageLiteral(resourceName: "Visible"), for: .normal)
                passwordDisplayButton!.imageView?.contentMode = .scaleAspectFit
                passwordDisplayButton!.contentEdgeInsets = UIEdgeInsetsMake(marginY, marginX, marginY, marginX)
                passwordDisplayButton!.addTarget(self, action: #selector(reversePasswordDisplay), for: UIControlEvents.touchUpInside)
                buttons = passwordDisplayButton
            }
        case .HOTP:
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
        default:
            passwordDisplayButton = nil
            buttons = nil
        }
    }
}
