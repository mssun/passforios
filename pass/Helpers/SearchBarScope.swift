//
//  SearchBarScope.swift
//  pass
//
//  Created by Danny Moesch on 05.03.19.
//  Copyright © 2019 Bob Sun. All rights reserved.
//

enum SearchBarScope: Int, CaseIterable {
    case current
    case all

    var localizedName: String {
        switch self {
        case .current:
            return "Current".localize()
        case .all:
            return "All".localize()
        }
    }
}
