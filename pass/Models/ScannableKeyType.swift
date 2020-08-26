//
//  ScannableKeyType.swift
//  pass
//
//  Created by Danny Moesch on 19.08.20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

enum ScannableKeyType {
    case pgpPublic
    case pgpPrivate
    case sshPrivate

    var visibility: String {
        switch self {
        case .pgpPublic:
            return "Public"
        case .pgpPrivate, .sshPrivate:
            return "Private"
        }
    }

    var headerStart: String {
        switch self {
        case .pgpPublic, .pgpPrivate:
            return "-----BEGIN PGP \(visibility.uppercased()) KEY BLOCK-----"
        case .sshPrivate:
            return "-----BEGIN"
        }
    }

    var footerStart: String {
        switch self {
        case .pgpPublic, .pgpPrivate:
            return "-----END PGP \(visibility.uppercased())"
        case .sshPrivate:
            return "-----END"
        }
    }

    var footerEnd: String {
        switch self {
        case .pgpPublic, .pgpPrivate:
            return "KEY BLOCK-----"
        case .sshPrivate:
            return "KEY-----"
        }
    }

    var counterType: Self? {
        switch self {
        case .pgpPublic:
            return .pgpPrivate
        case .pgpPrivate:
            return .pgpPublic
        case .sshPrivate:
            return nil
        }
    }
}
