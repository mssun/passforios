//
//  FillPasswordTableViewCell.swift
//  pass
//
//  Created by Mingshen Sun on 11/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import passKit

protocol FillPasswordTableViewCellDelegate {
    func generateAndCopyPassword()
    func showHidePasswordSettings()
}

class FillPasswordTableViewCell: UITableViewCell, ContentProvider {

    @IBOutlet weak var contentTextField: UITextField!
    var delegate: FillPasswordTableViewCellDelegate?

    @IBOutlet weak var settingButton: UIButton!
    @IBOutlet weak var generateButton: UIButton!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        contentTextField.font = Globals.passwordFont

        // Force aspect ratio of button images
        settingButton.imageView?.contentMode = .scaleAspectFit
        generateButton.imageView?.contentMode = .scaleAspectFit
    }

    @IBAction func generatePassword(_ sender: UIButton) {
        self.delegate?.generateAndCopyPassword()
    }

    @IBAction func showHidePasswordSettings() {
        self.delegate?.showHidePasswordSettings()
    }

    // re-color
    @IBAction func textFieldDidChange(_ sender: UITextField) {
        contentTextField.attributedText = Utils.attributedPassword(plainPassword: sender.text ?? "")
    }

    func getContent() -> String? {
        return contentTextField.attributedText?.string
    }

    func setContent(content: String?) {
        contentTextField.attributedText = Utils.attributedPassword(plainPassword: content ?? "")
    }
}
