//
//  Globals.swift
//  pass
//
//  Created by Mingshen Sun on 21/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import UIKit

class Globals {
    static let documentPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0];
    static let libraryPath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0];
    static let pgpPublicKeyPath = "\(documentPath)/gpg_key.pub"
    static let pgpPrivateKeyPath = "\(documentPath)/gpg_key"

    static let gitSSHPublicKeyPath = "\(documentPath)/ssh_key.pub"
    static let gitSSHPrivateKeyPath = "\(documentPath)/ssh_key"
    static let gitSSHPublicKeyURL = URL(fileURLWithPath: gitSSHPublicKeyPath)
    static let gitSSHPrivateKeyURL = URL(fileURLWithPath: gitSSHPrivateKeyPath)
    
    static let repositoryPath = "\(libraryPath)/password-store"
    static var passcodeConfiguration = PasscodeLockConfiguration()
    
    static let passwordDefaultLength = ["Random": (min: 6, max: 24, def: 16),
                                        "Apple":  (min: 15, max: 15, def: 15)]
    
    static let passwordDots = "••••••••••••"
    static let passwordFonts = "Menlo"
    
    // UI related
    static let red = UIColor(red:1.00, green:0.23, blue:0.19, alpha:1.0)
    static let blue = UIColor(red:0.00, green:0.48, blue:1.00, alpha:1.0)
    static let tableCellButtonSize = CGFloat(20.0)
    
    private init() { }
}

extension Bundle {
    var releaseVersionNumber: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
    var buildVersionNumber: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }
}
