//
//  StringExtension.swift
//  passKit
//
//  Created by Yishi Lin on 2018/9/23.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

import Foundation

public extension String {

    var trimmed: String {
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func stringByAddingPercentEncodingForRFC3986() -> String? {
        let unreserved = "-._~/?"
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: unreserved)
        return addingPercentEncoding(withAllowedCharacters: allowed)
    }
}

extension String {
    static func | (left: String, right: String) -> String {
        return right.isEmpty ? left : left + "\n" + right
    }
}
