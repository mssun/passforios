//
//  DefaultsKeys.swift
//  passKit
//
//  Created by Mingshen Sun on 21/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import SwiftyUserDefaults

public var Defaults = DefaultsAdapter(defaults: UserDefaults(suiteName: Globals.groupIdentifier)!, keyStore: DefaultsKeys())

public enum KeySource: String, DefaultsSerializable {
    case url, armor, file, itunes
}

public enum GitAuthenticationMethod: String, DefaultsSerializable {
    case password, key
}

extension SearchBarScope: DefaultsSerializable {}
extension PasswordGenerator: DefaultsSerializable {}

public extension DefaultsKeys {
    var pgpKeySource: DefaultsKey<KeySource?> { .init("pgpKeySource") }
    var pgpPublicKeyURL: DefaultsKey<URL?> { .init("pgpPublicKeyURL") }
    var pgpPrivateKeyURL: DefaultsKey<URL?> { .init("pgpPrivateKeyURL") }
    var isYubiKeyEnabled: DefaultsKey<Bool> { .init("isYubiKeyEnabled", defaultValue: false) }

    // Keep them for legacy reasons.
    var pgpPublicKeyArmor: DefaultsKey<String?> { .init("pgpPublicKeyArmor") }
    var pgpPrivateKeyArmor: DefaultsKey<String?> { .init("pgpPrivateKeyArmor") }
    var gitSSHPrivateKeyArmor: DefaultsKey<String?> { .init("gitSSHPrivateKeyArmor") }
    var passcodeKey: DefaultsKey<String?> { .init("passcodeKey") }

    var gitURL: DefaultsKey<URL> { .init("gitURL", defaultValue: URL(string: "https://")!) }
    var gitAuthenticationMethod: DefaultsKey<GitAuthenticationMethod> { .init("gitAuthenticationMethod", defaultValue: GitAuthenticationMethod.password) }
    var gitUsername: DefaultsKey<String> { .init("gitUsername", defaultValue: "git") }
    var gitBranchName: DefaultsKey<String> { .init("gitBranchName", defaultValue: "master") }
    var gitSSHPrivateKeyURL: DefaultsKey<URL?> { .init("gitSSHPrivateKeyURL") }
    var gitSSHKeySource: DefaultsKey<KeySource?> { .init("gitSSHKeySource") }
    var gitSignatureName: DefaultsKey<String?> { .init("gitSignatureName") }
    var gitSignatureEmail: DefaultsKey<String?> { .init("gitSignatureEmail") }

    var lastSyncedTime: DefaultsKey<Date?> { .init("lastSyncedTime") }

    var isHideUnknownOn: DefaultsKey<Bool> { .init("isHideUnknownOn", defaultValue: false) }
    var isHideOTPOn: DefaultsKey<Bool> { .init("isHideOTPOn", defaultValue: false) }
    var isRememberPGPPassphraseOn: DefaultsKey<Bool> { .init("isRememberPGPPassphraseOn", defaultValue: false) }
    var isRememberGitCredentialPassphraseOn: DefaultsKey<Bool> { .init("isRememberGitCredentialPassphraseOn", defaultValue: false) }
    var isEnableGPGIDOn: DefaultsKey<Bool> { .init("isEnableGPGIDOn", defaultValue: false) }
    var isShowFolderOn: DefaultsKey<Bool> { .init("isShowFolderOn", defaultValue: true) }
    var isHidePasswordImagesOn: DefaultsKey<Bool> { .init("isHidePasswordImagesOn", defaultValue: false) }
    var searchDefault: DefaultsKey<SearchBarScope?> { .init("searchDefault", defaultValue: .all) }
    var passwordGenerator: DefaultsKey<PasswordGenerator> { .init("passwordGenerator", defaultValue: PasswordGenerator()) }

    var encryptInArmored: DefaultsKey<Bool> { .init("encryptInArmored", defaultValue: false) }

    var autoCopyOTP: DefaultsKey<Bool> { .init("autoCopyOTP", defaultValue: false) }
}
