//
//  PasswordEntity.swift
//  pass
//
//  Created by Mingshen Sun on 11/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import SwiftyUserDefaults

extension PasswordEntity {
    public var nameWithCategory: String {
        if let path = path, path.hasSuffix(".gpg") {
            return String(path.prefix(upTo: path.index(path.endIndex, offsetBy: -4)))
        }
        return ""
    }

    public func getCategoryText() -> String {
        getCategoryArray().joined(separator: " > ")
    }

    public func getCategoryArray() -> [String] {
        var parentEntity = parent
        var passwordCategoryArray: [String] = []
        while parentEntity != nil {
            passwordCategoryArray.append(parentEntity!.name!)
            parentEntity = parentEntity!.parent
        }
        passwordCategoryArray.reverse()
        return passwordCategoryArray
    }

    public func getURL() throws -> URL {
        if let path = getPath().stringByAddingPercentEncodingForRFC3986(), let url = URL(string: path) {
            return url
        }
        throw AppError.unknown
    }

    // XXX: define some getters to get core data, we need to consider
    // manually write models instead auto generation.

    public func getImage() -> Data? {
        image
    }

    public func getName() -> String {
        // unwrap non-optional core data
        name ?? ""
    }

    public func getPath() -> String {
        // unwrap non-optional core data
        path ?? ""
    }
}
