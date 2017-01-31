//
//  Globals.swift
//  pass
//
//  Created by Mingshen Sun on 21/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation

class Globals {
    static let shared = Globals()
    let documentPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0];
    let secringPath = "\(NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])/secring.gpg"
    let sshPublicKeyPath = URL(fileURLWithPath: "\(NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])/ssh_key.pub")
    let sshPrivateKeyPath = URL(fileURLWithPath: "\(NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])/ssh_key")
    private init() { }
}
