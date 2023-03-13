//
//  SwitchTableViewCell.swift
//  pass
//
//  Created by Danny Moesch on 28.02.20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import passKit
import UIKit

class SwitchTableViewCell: UITableViewCell {
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var controlSwitch: UISwitch!

    private var updater: ((Bool) -> Void)!

    private weak var delegate: PasswordSettingSliderTableViewCellDelegate!

    @IBAction
    private func switchValueChanged(_: Any) {
        updater(controlSwitch.isOn)
        delegate.generateAndCopyPassword()
    }

    func set(title: String) -> SwitchTableViewCell {
        titleLabel.text = title
        return self
    }

    override func layoutMarginsDidChange() {
        layoutMargins.left = passKit.Globals.passwordGeneratorLeftLayoutMargin
    }

    func set(initialValue: Bool) -> SwitchTableViewCell {
        controlSwitch.isOn = initialValue
        return self
    }

    func updateNewValue(using updater: @escaping (Bool) -> Void) -> SwitchTableViewCell {
        self.updater = updater
        return self
    }

    func delegate(to delegate: PasswordSettingSliderTableViewCellDelegate) -> SwitchTableViewCell {
        self.delegate = delegate
        return self
    }
}
