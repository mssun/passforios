//
//  FillPasswordTableViewCell.swift
//  pass
//
//  Created by Mingshen Sun on 11/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import passKit
import UIKit

protocol FillPasswordTableViewCellDelegate: AnyObject {
    func generateAndCopyPassword()
    func showHidePasswordSettings()
}

class FillPasswordTableViewCell: UITableViewCell {
    @IBOutlet var contentTextField: UITextField!
    @IBOutlet var settingButton: UIButton!
    @IBOutlet var generateButton: UIButton!

    weak var delegate: FillPasswordTableViewCellDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        contentTextField.font = Globals.passwordFont

        // Force aspect ratio of button images
        settingButton.imageView?.contentMode = .scaleAspectFit
        generateButton.imageView?.contentMode = .scaleAspectFit
    }

    @IBAction
    private func generatePassword(_: UIButton) {
        delegate?.generateAndCopyPassword()
    }

    @IBAction
    private func showHidePasswordSettings() {
        delegate?.showHidePasswordSettings()
    }

    // re-color
    @IBAction
    private func textFieldDidChange(_ sender: UITextField) {
        contentTextField.attributedText = Utils.attributedPassword(plainPassword: sender.text ?? "")
    }

    func getContent() -> String? {
        contentTextField.attributedText?.string
    }

    func setContent(content: String?) {
        contentTextField.attributedText = Utils.attributedPassword(plainPassword: content ?? "")
    }
}
