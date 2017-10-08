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
    static let gitSSHPrivateKeyURL = DefaultsKey<URL?>("gitSSHPrivateKeyURL")
    static let gitSSHKeySource = DefaultsKey<String?>("gitSSHKeySource")
    static let gitSSHPrivateKeyArmor = DefaultsKey<String?>("gitSSHPrivateKeyArmor")
    static let gitSignatureName = DefaultsKey<String?>("gitSignatureName")
    static let gitSignatureEmail = DefaultsKey<String?>("gitSignatureEmail")

    static let lastSyncedTime = DefaultsKey<Date?>("lastSyncedTime")
    
    static let isTouchIDOn = DefaultsKey<Bool>("isTouchIDOn")
    static let passcodeKey = DefaultsKey<String?>("passcodeKey")
    
    static let isHideUnknownOn = DefaultsKey<Bool>("isHideUnknownOn")
    static let isHideOTPOn = DefaultsKey<Bool>("isHideOTPOn")
    static let isRememberPGPPassphraseOn = DefaultsKey<Bool>("isRememberPGPPassphraseOn")
    static let isRememberGitCredentialPassphraseOn = DefaultsKey<Bool>("isRememberGitCredentialPassphraseOn")
    static let isShowFolderOn = DefaultsKey<Bool>("isShowFolderOn")
    static let passwordGeneratorFlavor = DefaultsKey<String>("passwordGeneratorFlavor")
    
    static let encryptInArmored = DefaultsKey<Bool>("encryptInArmored")
}
