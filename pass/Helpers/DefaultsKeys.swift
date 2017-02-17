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
//    static let pgpKeyURL = DefaultsKey<URL?>("pgpKeyURL")
    static let pgpKeySource = DefaultsKey<String?>("pgpKeySource")
    static let pgpPublicKeyURL = DefaultsKey<URL?>("pgpPublicKeyURL")
    static let pgpPrivateKeyURL = DefaultsKey<URL?>("pgpPrivateKeyURL")
    
    static let pgpPublicKeyArmor = DefaultsKey<String?>("pgpPublicKeyArmor")
    static let pgpPrivateKeyArmor = DefaultsKey<String?>("pgpPrivateKeyArmor")
    
    static let pgpKeyPassphrase = DefaultsKey<String?>("pgpKeyPassphrase")
    static let pgpPrivateKeyURLPassphrase = DefaultsKey<String?>("pgpPrivateKeyURLPassphrase")
    static let pgpPrivateKeyArmorPassphrase = DefaultsKey<String?>("pgpPrivateKeyArmorPassphrase")
    static let pgpKeyID = DefaultsKey<String?>("pgpKeyID")
    static let pgpKeyUserID = DefaultsKey<String?>("pgpKeyUserID")
    
    static let gitRepositoryURL = DefaultsKey<URL?>("gitRepositoryURL")
    static let gitRepositoryAuthenticationMethod = DefaultsKey<String?>("gitRepositoryAuthenticationMethod")
    static let gitRepositoryUsername = DefaultsKey<String?>("gitRepositoryUsername")
    static let gitRepositoryPassword = DefaultsKey<String?>("gitRepositoryPassword")
    static let gitRepositorySSHPublicKeyURL = DefaultsKey<URL?>("gitRepositorySSHPublicKeyURL")
    static let gitRepositorySSHPrivateKeyURL = DefaultsKey<URL?>("gitRepositorySSHPrivateKeyURL")
    static let gitRepositorySSHPrivateKeyPassphrase = DefaultsKey<String?>("gitRepositorySSHPrivateKeyPassphrase")
    static let lastUpdatedTime = DefaultsKey<Date?>("lasteUpdatedTime")
    
    static let isTouchIDOn = DefaultsKey<Bool>("isTouchIDOn")
    static let passcodeKey = DefaultsKey<String?>("passcodeKey")
    
    static let isHideUnknownOn = DefaultsKey<Bool>("isHideUnknownOn")

}
