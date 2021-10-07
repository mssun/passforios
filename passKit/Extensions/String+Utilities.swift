//
//  String+Utilities.swift
//  passKit
//
//  Created by Yishi Lin on 2018/9/23.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

public extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func stringByAddingPercentEncodingForRFC3986() -> String? {
        let unreserved = "-._~/"
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: unreserved)
        return addingPercentEncoding(withAllowedCharacters: allowed)
    }

    func splitByNewline() -> [String] {
        split(omittingEmptySubsequences: false) { $0 == "\n" || $0 == "\r\n" }.map(Self.init)
    }
}

public extension String {
    static func | (left: String, right: String) -> String {
        right.isEmpty ? left : left + "\n" + right
    }
}
