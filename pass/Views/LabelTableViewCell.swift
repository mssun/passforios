//
//  LabelTableViewCell.swift
//  pass
//
//  Created by Mingshen Sun on 2/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import passKit
import SVProgressHUD
import UIKit

struct LabelTableViewCellData {
    var title: String
    var content: String
}

class LabelTableViewCell: UITableViewCell {
    @IBOutlet var contentLabel: UILabel!
    @IBOutlet var titleLabel: UILabel!

    private enum CellType {
        case password, URL, HOTP, other
    }

    private var type = CellType.other
    private var isReveal = false

    weak var delegatePasswordTableView: PasswordDetailTableViewController?

    private var passwordDisplayButton: UIButton?
    private var buttons: UIView?

    var cellData: LabelTableViewCellData? {
        didSet {
            guard let title = cellData?.title, let content = cellData?.content else {
                type = .other
                return
            }
            titleLabel.text = title
            if title.caseInsensitiveCompare("password") == .orderedSame {
                type = .password
                if isReveal {
                    contentLabel.attributedText = Utils.attributedPassword(plainPassword: content)
                } else {
                    if content.isEmpty {
                        contentLabel.text = ""
                    } else {
                        contentLabel.text = Globals.passwordDots
                    }
                }
                contentLabel.font = Globals.passwordFont
            } else if title.caseInsensitiveCompare("HmacBased".localize()) == .orderedSame {
                type = .HOTP
                if isReveal {
                    contentLabel.text = content
                } else {
                    contentLabel.text = Globals.oneTimePasswordDots
                }
                contentLabel.font = Globals.passwordFont
            } else if title.lowercased().contains("url") {
                type = .URL
                contentLabel.text = content
                contentLabel.font = UIFont.systemFont(ofSize: contentLabel.font.pointSize)
            } else {
                // default
                type = .other
                contentLabel.text = content
                contentLabel.font = UIFont.systemFont(ofSize: contentLabel.font.pointSize)
            }
            updateButtons()
        }
    }

    override var canBecomeFirstResponder: Bool {
        true
    }

    override func canPerformAction(_ action: Selector, withSender _: Any?) -> Bool {
        switch type {
        case .password:
            if isReveal {
                return action == #selector(copy(_:)) || action == #selector(concealPassword)
            }
            return action == #selector(copy(_:)) || action == #selector(revealPassword)
        case .URL:
            return action == #selector(copy(_:)) || action == #selector(openLink)
        case .HOTP:
            if isReveal {
                return action == #selector(copy(_:)) || action == #selector(concealPassword) || action == #selector(getNextHOTP)
            }
            return action == #selector(copy(_:)) || action == #selector(revealPassword) || action == #selector(getNextHOTP)
        default:
            return action == #selector(copy(_:))
        }
    }

    override func copy(_: Any?) {
        SecurePasteboard.shared.copy(textToCopy: cellData?.content)
    }

    @objc
    func revealPassword(_: Any?) {
        let plainPassword = cellData?.content ?? ""
        if type == .password {
            contentLabel.attributedText = Utils.attributedPassword(plainPassword: plainPassword)
        } else {
            contentLabel.text = plainPassword
        }
        isReveal = true
        passwordDisplayButton?.setImage(#imageLiteral(resourceName: "Invisible"), for: .normal)
    }

    @objc
    func concealPassword(_: Any?) {
        if type == .password {
            if cellData?.content.isEmpty == false {
                contentLabel.text = Globals.passwordDots
                contentLabel.textColor = Colors.label
            } else {
                contentLabel.text = ""
            }
        } else {
            contentLabel.text = Globals.oneTimePasswordDots
        }
        isReveal = false
        passwordDisplayButton?.setImage(#imageLiteral(resourceName: "Visible"), for: .normal)
    }

    @objc
    func reversePasswordDisplay(_ sender: Any?) {
        if isReveal {
            // conceal
            concealPassword(sender)
        } else {
            // reveal
            revealPassword(sender)
        }
    }

    @objc
    func openLink(_: Any?) {
        // if isURLCell, passwordTableView should not be nil
        delegatePasswordTableView!.openLink(to: cellData?.content)
    }

    @objc
    func getNextHOTP(_: Any?) {
        // if isHOTPCell, passwordTableView should not be nil
        delegatePasswordTableView!.getNextHOTP()
    }

    private func updateButtons() {
        // total width and height of a button
        let height = min(bounds.height, 36.0)
        let width = max(height * 0.8, Globals.tableCellButtonSize)

        // margins (between button boundary and icon)
        let marginY = max((height - Globals.tableCellButtonSize) / 2, 0.0)
        let marginX = max((width - Globals.tableCellButtonSize) / 2, 0.0)

        switch type {
        case .password:
            if let content = cellData?.content, !content.isEmpty {
                // password button
                passwordDisplayButton = UIButton(type: .system)
                passwordDisplayButton!.frame = CGRect(x: 0, y: 0, width: width, height: height)
                passwordDisplayButton!.setImage(#imageLiteral(resourceName: "Visible"), for: .normal)
                passwordDisplayButton!.imageView?.contentMode = .scaleAspectFit
                passwordDisplayButton!.contentEdgeInsets = UIEdgeInsets(top: marginY, left: marginX, bottom: marginY, right: marginX)
                passwordDisplayButton!.addTarget(self, action: #selector(reversePasswordDisplay), for: UIControl.Event.touchUpInside)
                buttons = passwordDisplayButton
            }
        case .HOTP:
            // hotp button
            let nextButton = UIButton(type: .system)
            nextButton.frame = CGRect(x: 0, y: 0, width: width, height: height)
            nextButton.setImage(#imageLiteral(resourceName: "Refresh"), for: .normal)
            nextButton.imageView?.contentMode = .scaleAspectFit
            nextButton.contentEdgeInsets = UIEdgeInsets(top: marginY, left: marginX, bottom: marginY, right: marginX)
            nextButton.addTarget(self, action: #selector(getNextHOTP), for: UIControl.Event.touchUpInside)

            // password button
            passwordDisplayButton = UIButton(type: .system)
            passwordDisplayButton!.frame = CGRect(x: width, y: 0, width: width, height: height)

            passwordDisplayButton!.setImage(#imageLiteral(resourceName: "Visible"), for: .normal)
            passwordDisplayButton!.imageView?.contentMode = .scaleAspectFit
            passwordDisplayButton!.contentEdgeInsets = UIEdgeInsets(top: marginY, left: marginX, bottom: marginY, right: marginX)
            passwordDisplayButton!.addTarget(self, action: #selector(reversePasswordDisplay), for: UIControl.Event.touchUpInside)

            buttons = UIView()
            buttons!.frame = CGRect(x: 0, y: 0, width: width * 2, height: height)
            buttons!.addSubview(nextButton)
            buttons!.addSubview(passwordDisplayButton!)
        default:
            passwordDisplayButton = nil
            buttons = nil
        }
        accessoryView = buttons
    }
}
