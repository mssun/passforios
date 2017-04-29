//
//  DefaultKeys.swift
//  pass
//
//  Created by Mingshen Sun on 21/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import SwiftyUserDefaults

extension DefaultsKeys {
    static let pgpKeySource = DefaultsKey<String?>("pgpKeySource")
    static let pgpPublicKeyURL = DefaultsKey<URL?>("pgpPublicKeyURL")
    static let pgpPrivateKeyURL = DefaultsKey<URL?>("pgpPrivateKeyURL")
    
    static let pgpPublicKeyArmor = DefaultsKey<String?>("pgpPublicKeyArmor")
    static let pgpPrivateKeyArmor = DefaultsKey<String?>("pgpPrivateKeyArmor")
    
    static let gitURL = DefaultsKey<URL?>("gitURL")
    static let gitAuthenticationMethod = DefaultsKey<String?>("gitAuthenticationMethod")
    static let gitUsername = DefaultsKey<String?>("gitUsername")
    static let gitSSHPublicKeyURL = DefaultsKey<URL?>("gitSSHPublicKeyURL")
    static let gitSSHPrivateKeyURL = DefaultsKey<URL?>("gitSSHPrivateKeyURL")
    static let gitSSHKeySource = DefaultsKey<String?>("gitSSHKeySource")
    static let gitSSHPublicKeyArmor = DefaultsKey<String?>("gitSSHPublicKeyArmor")
    static let gitSSHPrivateKeyArmor = DefaultsKey<String?>("gitSSHPrivateKeyArmor")
    static let gitSignatureName = DefaultsKey<String?>("gitSignatureName")
    static let gitSignatureEmail = DefaultsKey<String?>("gitSignatureEmail")

    static let lastSyncedTime = DefaultsKey<Date?>("lastSyncedTime")
    
    static let isTouchIDOn = DefaultsKey<Bool>("isTouchIDOn")
    static let passcodeKey = DefaultsKey<String?>("passcodeKey")
    
    static let isHideUnknownOn = DefaultsKey<Bool>("isHideUnknownOn")
    static let isHideOTPOn = DefaultsKey<Bool>("isHideOTPOn")
    static let isRememberPassphraseOn = DefaultsKey<Bool>("isRememberPassphraseOn")
    static let isShowFolderOn = DefaultsKey<Bool>("isShowFolderOn")
    static let passwordGeneratorFlavor = DefaultsKey<String>("passwordGeneratorFlavor")
    
    static let encryptInArmored = DefaultsKey<Bool>("encryptInArmored")
}
