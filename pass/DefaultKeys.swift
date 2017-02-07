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
    static let pgpKeyURL = DefaultsKey<URL?>("pgpKeyURL")

    static let pgpKeyPassphrase = DefaultsKey<String>("pgpKeyPassphrase")
    static let pgpKeyID = DefaultsKey<String>("pgpKeyID")
    static let pgpKeyUserID = DefaultsKey<String>("pgpKeyUserID")
    
    static let gitRepositoryURL = DefaultsKey<URL?>("gitRepositoryURL")
    static let gitRepositoryAuthenticationMethod = DefaultsKey<String>("gitRepositoryAuthenticationMethod")
    static let gitRepositoryUsername = DefaultsKey<String>("gitRepositoryUsername")
    static let gitRepositoryPassword = DefaultsKey<String>("gitRepositoryPassword")
    static let gitRepositorySSHPublicKeyURL = DefaultsKey<URL?>("gitRepositorySSHPublicKeyURL")
    static let gitRepositorySSHPrivateKeyURL = DefaultsKey<URL?>("gitRepositorySSHPrivateKeyURL")
    static let gitRepositorySSHPrivateKeyPassphrase = DefaultsKey<String?>("gitRepositorySSHPrivateKeyPassphrase")
    static let lastUpdatedTime = DefaultsKey<Date?>("lasteUpdatedTime")
    
    static let isPasscodeOn = DefaultsKey<Bool>("isPasscodeOn")
    static let isTouchIDOn = DefaultsKey<Bool>("isTouchIDOn")
}
