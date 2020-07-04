/*
 String+Localization.swift
 passKit

 Created by Danny Moesch on 12.01.19.
 Copyright © 2019 Bob Sun. All rights reserved.
 */

extension String {
    public func localize() -> String {
        // swiftlint:disable:next nslocalizedstring_key
        NSLocalizedString(self, bundle: Bundle.main, value: "#\(self)#", comment: "")
    }

    public func localize(_ firstValue: CVarArg) -> String {
        String(format: localize(), firstValue)
    }

    public func localize(_ firstValue: CVarArg, _ secondValue: CVarArg) -> String {
        String(format: localize(), firstValue, secondValue)
    }

    public func localize(_ error: Error) -> String {
        localize(error.localizedDescription)
    }
}
