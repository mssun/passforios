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
        if let p = path, p.hasSuffix(".gpg") {
            return String(p.prefix(upTo: p.index(p.endIndex, offsetBy: -4)))
        }
        return ""
    }

    public func getCategoryText() -> String {
        return getCategoryArray().joined(separator: " > ")
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

    public func getURL() -> URL? {
        if let p = getPath().stringByAddingPercentEncodingForRFC3986() {
            return URL(string: p)
        }
        return nil
    }

    // XXX: define some getters to get core data, we need to consider
    // manually write models instead auto generation.

    public func getImage() -> Data? {
        return image
    }

    public func getName() -> String {
        // unwrap non-optional core data
        return name ?? ""
    }

    public func getPath() -> String {
        // unwrap non-optional core data
        return path ?? ""
    }

}
