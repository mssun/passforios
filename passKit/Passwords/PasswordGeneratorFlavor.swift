//
//  PasswordGeneratorFlavor.swift
//  passKit
//
//  Created by Danny Moesch on 28.11.18.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

public typealias LengthLimits = (min: Int, max: Int)

public enum PasswordGeneratorFlavor: String {
    case random = "Random"
    case xkcd = "XKCD"

    public var localized: String {
        rawValue.localize()
    }

    public var lengthLimits: LengthLimits {
        switch self {
        case .random:
            return (4, 64)
        case .xkcd:
            return (2, 5)
        }
    }
}

extension PasswordGeneratorFlavor: CaseIterable {}
