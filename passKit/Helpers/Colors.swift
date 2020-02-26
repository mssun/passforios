//
//  Colors.swift
//  passKit
//
//  Created by Danny Moesch on 01.10.19.
//  Copyright © 2019 Bob Sun. All rights reserved.
//

public struct Colors {
    public static let label: UIColor = {
        if #available(iOS 13.0, *) {
            return .label
        }
        return .black
    }()

    public static let secondaryLabel: UIColor = {
        if #available(iOS 13.0, *) {
            return .secondaryLabel
        }
        return .init(red: 60.0, green: 60.0, blue: 67.0, alpha: 0.6)
    }()

    public static let systemBackground: UIColor = {
        if #available(iOS 13.0, *) {
            return .systemBackground
        }
        return .white
    }()

    public static let secondarySystemBackground: UIColor = {
        if #available(iOS 13.0, *) {
            return .secondarySystemBackground
        }
        return .init(red: 242.0, green: 242.0, blue: 247.0, alpha: 1.0)
    }()

    public static let systemRed: UIColor = {
        return .systemRed
    }()

    public static let systemBlue: UIColor = {
        return .systemBlue
    }()
}
