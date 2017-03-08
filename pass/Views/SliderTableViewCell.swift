//
//  SliderTableViewCell.swift
//  pass
//
//  Created by Yishi Lin on 8/3/17.
//  Copyright © 2017 Yishi Lin. All rights reserved.
//


import UIKit

class SliderTableViewCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var slider: UISlider!
    
    var roundedValue: Int {
        get {
            return Int(slider.value)
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
        let roundedValue = round(sender.value)
        sender.value = roundedValue
        valueLabel.text = "\(Int(roundedValue))"
    }
    
    func reset(title: String, minimumValue: Int, maximumValue: Int, defaultValue: Int) {
        titleLabel.text = title
        slider.minimumValue = Float(minimumValue)
        slider.maximumValue = Float(maximumValue)
        slider.value = Float(defaultValue)
        valueLabel.text = String(defaultValue)
    }
    
}
