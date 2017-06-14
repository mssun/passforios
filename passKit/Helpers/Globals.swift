//
//  Globals.swift
//  pass
//
//  Created by Mingshen Sun on 21/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import UIKit

public class Globals {
    
    // Legacy paths (not shared)
    public static let documentPathLegacy = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0];
    public static let libraryPathLegacy = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0];
    public static let pgpPublicKeyPathLegacy = "\(documentPathLegacy)/gpg_key.pub"
    public static let pgpPrivateKeyPathLegacy = "\(documentPathLegacy)/gpg_key"
    public static let gitSSHPrivateKeyPathLegacy = "\(documentPathLegacy)/ssh_key"
    public static let gitSSHPrivateKeyURLLegacy = URL(fileURLWithPath: gitSSHPrivateKeyPathLegacy)
    public static let repositoryPathLegacy = "\(libraryPathLegacy)/password-store"
    
    public static let bundleIdentifier = "me.mssun.passforios"
    public static let groupIdentifier = "group." + bundleIdentifier
    public static let passKitBundleIdentifier = bundleIdentifier + ".passKit"
    
    public static let sharedContainerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)!
    public static let documentPath = sharedContainerURL.appendingPathComponent("Documents").path
    public static let libraryPath = sharedContainerURL.appendingPathComponent("Library").path
    public static let pgpPublicKeyPath = documentPath + "/gpg_key.pub"
    public static let pgpPrivateKeyPath = documentPath + "/gpg_key"
    public static let gitSSHPrivateKeyPath = documentPath + "/ssh_key"
    public static let gitSSHPrivateKeyURL = URL(fileURLWithPath: gitSSHPrivateKeyPath)
    public static let repositoryPath = libraryPath + "/password-store"
    public static let dbPath = documentPath + "/pass.sqlite"
    
    public static let iTunesFileSharingPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    public static let iTunesFileSharingPGPPublic = iTunesFileSharingPath + "/gpg_key.pub"
    public static let iTunesFileSharingPGPPrivate = iTunesFileSharingPath + "/gpg_key"
    public static let iTunesFileSharingSSHPrivate = iTunesFileSharingPath + "/ssh_key"
    
    public static let passwordDefaultLength = ["Random": (min: 4, max: 64, def: 16),
                                        "Apple":  (min: 15, max: 15, def: 15)]
    
    public static let gitSignatureDefaultName = "Pass for iOS"
    public static let gitSignatureDefaultEmail = "user@passforios"
    
    public static let passwordDots = "••••••••••••"
    public static let oneTimePasswordDots = "••••••"
    public static let passwordFonts = "Menlo"
    
    // UI related
    public static let red = UIColor(red:1.00, green:0.23, blue:0.19, alpha:1.0)
    public static let blue = UIColor(red:0.00, green:0.48, blue:1.00, alpha:1.0)
    public static let tableCellButtonSize = CGFloat(20.0)
    
    private init() { }
}

public extension Bundle {
    var releaseVersionNumber: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
    var buildVersionNumber: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }
}
