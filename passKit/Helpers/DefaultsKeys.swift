//
//  DefaultsKeys.swift
//  passKit
//
//  Created by Mingshen Sun on 21/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import SwiftyUserDefaults

// Workaround for Xcode 13: https://github.com/sunshinejr/SwiftyUserDefaults/issues/285

extension DefaultsSerializable {
    public static var _defaultsArray: DefaultsArrayBridge<[T]> { return DefaultsArrayBridge() }
}
extension Date: DefaultsSerializable {
    public static var _defaults: DefaultsObjectBridge<Date> { return DefaultsObjectBridge() }
}
extension String: DefaultsSerializable {
    public static var _defaults: DefaultsStringBridge { return DefaultsStringBridge() }
}
extension Int: DefaultsSerializable {
    public static var _defaults: DefaultsIntBridge { return DefaultsIntBridge() }
}
extension Double: DefaultsSerializable {
    public static var _defaults: DefaultsDoubleBridge { return DefaultsDoubleBridge() }
}
extension Bool: DefaultsSerializable {
    public static var _defaults: DefaultsBoolBridge { return DefaultsBoolBridge() }
}
extension Data: DefaultsSerializable {
    public static var _defaults: DefaultsDataBridge { return DefaultsDataBridge() }
}

extension URL: DefaultsSerializable {
    #if os(Linux)
    public static var _defaults: DefaultsKeyedArchiverBridge<URL> { return DefaultsKeyedArchiverBridge() }
    #else
    public static var _defaults: DefaultsUrlBridge { return DefaultsUrlBridge() }
    #endif
    public static var _defaultsArray: DefaultsKeyedArchiverBridge<[URL]> { return DefaultsKeyedArchiverBridge() }
}

extension DefaultsSerializable where Self: Codable {
    public static var _defaults: DefaultsCodableBridge<Self> { return DefaultsCodableBridge() }
    public static var _defaultsArray: DefaultsCodableBridge<[Self]> { return DefaultsCodableBridge() }
}

extension DefaultsSerializable where Self: RawRepresentable {
    public static var _defaults: DefaultsRawRepresentableBridge<Self> { return DefaultsRawRepresentableBridge() }
    public static var _defaultsArray: DefaultsRawRepresentableArrayBridge<[Self]> { return DefaultsRawRepresentableArrayBridge() }
}

extension DefaultsSerializable where Self: NSCoding {
    public static var _defaults: DefaultsKeyedArchiverBridge<Self> { return DefaultsKeyedArchiverBridge() }
    public static var _defaultsArray: DefaultsKeyedArchiverBridge<[Self]> { return DefaultsKeyedArchiverBridge() }
}

extension Dictionary: DefaultsSerializable where Key == String {
    public typealias T = [Key: Value]
    public typealias Bridge = DefaultsObjectBridge<T>
    public typealias ArrayBridge = DefaultsArrayBridge<[T]>
    public static var _defaults: Bridge { return Bridge() }
    public static var _defaultsArray: ArrayBridge { return ArrayBridge() }
}
extension Array: DefaultsSerializable where Element: DefaultsSerializable {
    public typealias T = [Element.T]
    public typealias Bridge = Element.ArrayBridge
    public typealias ArrayBridge = DefaultsObjectBridge<[T]>
    public static var _defaults: Bridge {
        return Element._defaultsArray
    }
    public static var _defaultsArray: ArrayBridge {
        fatalError("Multidimensional arrays are not supported yet")
    }
}


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
