//
//  AdditionField.swift
//  passKit
//
//  Created by Danny Moesch on 30.09.18.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

public struct AdditionField: Hashable {
    public let title: String, content: String

    public init(title: String = "", content: String = "") {
        self.title = title
        self.content = content
    }

    var asString: String {
        title.isEmpty ? content : title + ": " + content
    }

    var asTuple: (String, String) {
        return (title, content)
    }
}

extension AdditionField {
    static func | (left: String, right: AdditionField) -> String {
        left | right.asString
    }

    static func | (left: AdditionField, right: String) -> String {
        left.asString | right
    }

    static func | (left: AdditionField, right: AdditionField) -> String {
        left.asString | right
    }
}

infix operator =>: MultiplicationPrecedence
public func => (key: String, value: String) -> AdditionField {
    AdditionField(title: key, content: value)
}
