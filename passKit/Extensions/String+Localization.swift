//
//  String+Localization.swift
//  passKit
//
//  Created by Danny Moesch on 12.01.19.
//  Copyright © 2019 Bob Sun. All rights reserved.
//

public extension String {
    func localize() -> String {
        // swiftlint:disable:next nslocalizedstring_key
        NSLocalizedString(self, bundle: Bundle.main, value: "#\(self)#", comment: "")
    }

    func localize(_ firstValue: CVarArg) -> String {
        String(format: localize(), firstValue)
    }

    func localize(_ firstValue: CVarArg, _ secondValue: CVarArg) -> String {
        String(format: localize(), firstValue, secondValue)
    }

    func localize(_ error: Error) -> String {
        localize(error.localizedDescription)
    }
}
