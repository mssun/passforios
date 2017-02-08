//
//  Globals.swift
//  pass
//
//  Created by Mingshen Sun on 21/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation

class Globals {
    static let documentPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0];
    static let secringPath = "\(documentPath)/secring.gpg"
    static let sshPublicKeyPath = URL(fileURLWithPath: "\(documentPath)/ssh_key.pub")
    static let sshPrivateKeyPath = URL(fileURLWithPath: "\(documentPath)/ssh_key")
    static var passcodeConfiguration = PasscodeLockConfiguration()
    private init() { }
}
