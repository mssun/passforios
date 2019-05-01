//
//  DefaultKeys.swift
//  pass
//
//  Created by Mingshen Sun on 21/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import SwiftyUserDefaults

public var SharedDefaults = UserDefaults(suiteName: Globals.groupIdentifier)!

public extension DefaultsKeys {
    static let pgpKeySource = DefaultsKey<String?>("pgpKeySource")
    static let pgpPublicKeyURL = DefaultsKey<URL?>("pgpPublicKeyURL")
    static let pgpPrivateKeyURL = DefaultsKey<URL?>("pgpPrivateKeyURL")

    static let pgpPublicKeyArmor = DefaultsKey<String?>("pgpPublicKeyArmor")
    static let pgpPrivateKeyArmor = DefaultsKey<String?>("pgpPrivateKeyArmor")

    static let gitURL = DefaultsKey<URL?>("gitURL")
    static let gitAuthenticationMethod = DefaultsKey<String?>("gitAuthenticationMethod")
    static let gitUsername = DefaultsKey<String?>("gitUsername")
    static let gitBranchName = DefaultsKey<String?>("gitBranchName")
    static let gitSSHPrivateKeyURL = DefaultsKey<URL?>("gitSSHPrivateKeyURL")
    static let gitSSHKeySource = DefaultsKey<String?>("gitSSHKeySource")
    static let gitSSHPrivateKeyArmor = DefaultsKey<String?>("gitSSHPrivateKeyArmor")
    static let gitSignatureName = DefaultsKey<String?>("gitSignatureName")
    static let gitSignatureEmail = DefaultsKey<String?>("gitSignatureEmail")

    static let lastSyncedTime = DefaultsKey<Date?>("lastSyncedTime")

    static let isTouchIDOn = DefaultsKey<Bool>("isTouchIDOn", defaultValue: false)
    static let passcodeKey = DefaultsKey<String?>("passcodeKey")

    static let isHideUnknownOn = DefaultsKey<Bool>("isHideUnknownOn", defaultValue: false)
    static let isHideOTPOn = DefaultsKey<Bool>("isHideOTPOn", defaultValue: false)
    static let isRememberPGPPassphraseOn = DefaultsKey<Bool>("isRememberPGPPassphraseOn", defaultValue: false)
    static let isRememberGitCredentialPassphraseOn = DefaultsKey<Bool>("isRememberGitCredentialPassphraseOn", defaultValue: false)
    static let isShowFolderOn = DefaultsKey<Bool>("isShowFolderOn", defaultValue: true)
    static let isHidePasswordImagesOn = DefaultsKey<Bool>("isHidePasswordImagesOn", defaultValue: false)
    static let isSearchDefaultAll = DefaultsKey<Bool>("isSearchDefaultAll", defaultValue: true)
    static let passwordGeneratorFlavor = DefaultsKey<String>("passwordGeneratorFlavor", defaultValue: "Apple")

    static let encryptInArmored = DefaultsKey<Bool>("encryptInArmored", defaultValue: false)
}
