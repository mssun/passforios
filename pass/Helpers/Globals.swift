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
    
    // Legacy paths (not shared)
    static let documentPathLegacy = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0];
    static let libraryPathLegacy = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0];
    static let pgpPublicKeyPathLegacy = "\(documentPathLegacy)/gpg_key.pub"
    static let pgpPrivateKeyPathLegacy = "\(documentPathLegacy)/gpg_key"
    static let gitSSHPrivateKeyPathLegacy = "\(documentPathLegacy)/ssh_key"
    static let gitSSHPrivateKeyURLLegacy = URL(fileURLWithPath: gitSSHPrivateKeyPathLegacy)
    static let repositoryPathLegacy = "\(libraryPathLegacy)/password-store"
    
    static let groupIdentifier = "group." + Bundle.main.bundleIdentifier!
    static let sharedContainerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)!
    static let documentPath = sharedContainerURL.appendingPathComponent("Keys").path
    static let libraryPath = sharedContainerURL.appendingPathComponent("Repository").path
    static let pgpPublicKeyPath = documentPath + "/gpg_key.pub"
    static let pgpPrivateKeyPath = documentPath + "/gpg_key"
    static let gitSSHPrivateKeyPath = documentPath + "/ssh_key"
    static let gitSSHPrivateKeyURL = URL(fileURLWithPath: gitSSHPrivateKeyPath)
    static let repositoryPath = libraryPath + "/password-store"
    
    static var passcodeConfiguration = PasscodeLockConfiguration()
    
    static let passwordDefaultLength = ["Random": (min: 4, max: 64, def: 16),
                                        "Apple":  (min: 15, max: 15, def: 15)]
    
    static let gitSignatureDefaultName = "Pass for iOS"
    static let gitSignatureDefaultEmail = "user@passforios"
    
    static let passwordDots = "••••••••••••"
    static let oneTimePasswordDots = "••••••"
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
