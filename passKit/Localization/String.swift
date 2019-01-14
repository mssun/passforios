/*
 String.swift
 passKit

 Created by Danny Moesch on 12.01.19.
 Copyright © 2019 Bob Sun. All rights reserved.
 */

extension String {
    public func localize() -> String {
        return NSLocalizedString(self, value: "#\(self)#", comment: "")
    }

    public func localize(_ firstValue: CVarArg) -> String {
        return String(format: localize(), firstValue)
    }

    public func localize(_ firstValue: CVarArg, _ secondValue: CVarArg) -> String {
        return String(format: localize(), firstValue, secondValue)
    }

    public func localize(_ error: Error) -> String {
        return localize(error.localizedDescription)
    }
}
