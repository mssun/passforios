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
    static let sshPublicKeyURL = URL(fileURLWithPath: "\(documentPath)/ssh_key.pub")
    static let sshPrivateKeyURL = URL(fileURLWithPath: "\(documentPath)/ssh_key")
    static var passcodeConfiguration = PasscodeLockConfiguration()
    static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
    private init() { }
}
