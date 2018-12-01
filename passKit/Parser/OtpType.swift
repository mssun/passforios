//
//  OtpType.swift
//  passKit
//
//  Created by Danny Moesch on 01.12.2018.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

import OneTimePassword

public enum OtpType {
    case totp, hotp, none

    init(token: Token?) {
        switch token?.generator.factor {
        case .some(.counter):
            self = .hotp
        case .some(.timer):
            self = .totp
        default:
            self = .none
        }
    }

    init(name: String?) {
        switch name?.lowercased() {
        case Constants.HOTP:
            self = .hotp
        case Constants.TOTP:
            self = .totp
        default:
            self = .none
        }
    }
}
