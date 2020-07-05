//
//  SliderTableViewCell.swift
//  pass
//
//  Created by Yishi Lin on 8/3/17.
//  Copyright © 2017 Yishi Lin. All rights reserved.
//

import passKit
import UIKit

class SliderTableViewCell: UITableViewCell {
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var valueLabel: UILabel!
    @IBOutlet var slider: UISlider!

    private var checker: ((Int) -> Bool)!
    private var updater: ((Int) -> Void)!

    private weak var delegate: PasswordSettingSliderTableViewCellDelegate!

    @IBAction
    private func handleSliderValueChange(_ sender: UISlider) {
        let newRoundedValue = Int(sender.value)
        // Proceed only if the rounded value gets updated.
        guard checker(newRoundedValue) else {
            return
        }
        sender.value = Float(newRoundedValue)
        valueLabel.text = "\(newRoundedValue)"

        updater(newRoundedValue)
        delegate.generateAndCopyPassword()
    }

    func set(title: String) -> SliderTableViewCell {
        titleLabel.text = title
        return self
    }

    func configureSlider(with configuration: LengthLimits) -> SliderTableViewCell {
        slider.minimumValue = Float(configuration.min)
        slider.maximumValue = Float(configuration.max)
        return self
    }

    func set(initialValue: Int) -> SliderTableViewCell {
        slider.value = Float(initialValue)
        valueLabel.text = String(initialValue)
        return self
    }

    func checkNewValue(with checker: @escaping (Int) -> Bool) -> SliderTableViewCell {
        self.checker = checker
        return self
    }

    func updateNewValue(using updater: @escaping (Int) -> Void) -> SliderTableViewCell {
        self.updater = updater
        return self
    }

    func delegate(to delegate: PasswordSettingSliderTableViewCellDelegate) -> SliderTableViewCell {
        self.delegate = delegate
        return self
    }
}

extension SliderTableViewCell: ContentProvider {
    func getContent() -> String? {
        nil
    }

    func setContent(content _: String?) {}
}
