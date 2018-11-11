//
//  PasswordHelpers.swift
//  passKit
//
//  Created by Danny Moesch on 17.08.18.
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
}

enum PasswordChange: Int {
    case path = 0x01
    case content = 0x02
    case none = 0x00
}
