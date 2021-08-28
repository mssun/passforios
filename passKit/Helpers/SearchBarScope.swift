//
//  SearchBarScope.swift
//  passKit
//
//  Created by Danny Moesch on 05.03.19.
//  Copyright © 2019 Bob Sun. All rights reserved.
//

import SwiftyUserDefaults

public enum SearchBarScope: Int {
    case current
    case all

    public var localizedName: String {
        switch self {
        case .current:
            return "Current".localize()
        case .all:
            return "All".localize()
        }
    }
}

extension SearchBarScope: CaseIterable {}
