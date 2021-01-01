//
//  PasswordSelectionDelegate.swift
//  passAutoFillExtension
//
//  Created by Sun, Mingshen on 12/31/20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import passKit

protocol PasswordSelectionDelegate: AnyObject {
    func selected(password: PasswordTableEntry)
}
