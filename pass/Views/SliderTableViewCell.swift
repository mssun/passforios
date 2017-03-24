//
//  SliderTableViewCell.swift
//  pass
//
//  Created by Yishi Lin on 8/3/17.
//  Copyright © 2017 Yishi Lin. All rights reserved.
//


import UIKit

protocol PasswordSettingSliderTableViewCellDelegate {
    func generateAndCopyPassword()
}

class SliderTableViewCell: ContentTableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var slider: UISlider!
    
    var delegate: UITableViewController?
    
    var roundedValue: Int {
        get {
            return Int(valueLabel.text!)!
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    @IBAction func handleSliderValueChange(_ sender: UISlider) {
        let oldRoundedValue = self.roundedValue
        let newRoundedValue = Int(sender.value)
        // proceed only when the rounded value gets updated
        guard newRoundedValue != oldRoundedValue else {
            return;
        }
        sender.value = Float(newRoundedValue)
        valueLabel.text = "\(newRoundedValue)"
        if let delegate: PasswordSettingSliderTableViewCellDelegate = self.delegate as? PasswordSettingSliderTableViewCellDelegate {
            delegate.generateAndCopyPassword()
        }
    }
    
    func reset(title: String, minimumValue: Int, maximumValue: Int, defaultValue: Int) {
        titleLabel.text = title
        slider.minimumValue = Float(minimumValue)
        slider.maximumValue = Float(maximumValue)
        slider.value = Float(defaultValue)
        valueLabel.text = String(defaultValue)
    }
    
}
