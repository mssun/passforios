//
//  String+Utilities.swift
//  passKit
//
//  Created by Yishi Lin on 2018/9/23.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

extension String {
    public var trimmed: String {
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func stringByAddingPercentEncodingForRFC3986() -> String? {
        let unreserved = "-._~/?"
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: unreserved)
        return addingPercentEncoding(withAllowedCharacters: allowed)
    }

    public func splitByNewline() -> [String] {
        return split(omittingEmptySubsequences: false) { $0 == "\n" || $0 == "\r\n" }.map(String.init)
    }
}

extension String {
    public static func | (left: String, right: String) -> String {
        return right.isEmpty ? left : left + "\n" + right
    }
}
