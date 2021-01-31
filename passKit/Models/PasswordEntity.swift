//
//  PasswordEntity.swift
//  pass
//
//  Created by Mingshen Sun on 11/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import SwiftyUserDefaults

public extension PasswordEntity {
    var nameWithCategory: String {
        if let path = path {
            if path.hasSuffix(".gpg") {
                return String(path.prefix(upTo: path.index(path.endIndex, offsetBy: -4)))
            }
            return path
        }
        return ""
    }

    func getCategoryText() -> String {
        getCategoryArray().joined(separator: " > ")
    }

    func getCategoryArray() -> [String] {
        var parentEntity = parent
        var passwordCategoryArray: [String] = []
        while parentEntity != nil {
            passwordCategoryArray.append(parentEntity!.name!)
            parentEntity = parentEntity!.parent
        }
        passwordCategoryArray.reverse()
        return passwordCategoryArray
    }

    func getURL() throws -> URL {
        if let path = getPath().stringByAddingPercentEncodingForRFC3986(), let url = URL(string: path) {
            return url
        }
        throw AppError.unknown
    }

    // XXX: define some getters to get core data, we need to consider
    // manually write models instead auto generation.

    func getImage() -> Data? {
        image
    }

    func getName() -> String {
        // unwrap non-optional core data
        name ?? ""
    }

    func getPath() -> String {
        // unwrap non-optional core data
        path ?? ""
    }
}
