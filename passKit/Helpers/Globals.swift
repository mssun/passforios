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

    public static let gitPassword = "gitPassword"
    public static let gitSSHPrivateKeyPassphrase = "gitSSHPrivateKeyPassphrase"
    public static let pgpKeyPassphrase = "pgpKeyPassphrase"
    
    public static let gitSignatureDefaultName = "Pass for iOS"
    public static let gitSignatureDefaultEmail = "user@passforios"

    public static let passwordDots = "••••••••••••"
    public static let oneTimePasswordDots = "••••••"
    public static let passwordFont = UIFont(name: "Courier-Bold", size: UIFont.labelFontSize - 1)

    // UI related
    public static let red = UIColor(red:1.00, green:0.23, blue:0.19, alpha:1.0)
    public static let blue = UIColor(red:0.00, green:0.48, blue:1.00, alpha:1.0)
    public static let letterColor = UIColor(red:40/255.0, green:42/255.0, blue:54/255.0, alpha:1.0)
    public static let symbolColor = UIColor(red:200/255.0, green:40/255.0, blue:41/255.0, alpha:1.0)
    public static let digitColor = UIColor(red:66/255.0, green:113/255.0, blue:174/255.0, alpha:1.0)
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
