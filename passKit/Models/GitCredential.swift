//
//  GitCredential.swift
//  pass
//
//  Created by Mingshen Sun on 30/4/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import UIKit
import SwiftyUserDefaults
import ObjectiveGit

public struct GitCredential {
    private var credential: Credential
    
    public enum Credential {
        case http(userName: String)
        case ssh(userName: String, privateKeyFile: URL)
    }
    
    public init(credential: Credential) {
        self.credential = credential
    }
    
    public func credentialProvider(requestGitPassword: @escaping (Credential, String?) -> String?) throws -> GTCredentialProvider {
        var attempts = 0
        var lastPassword: String? = nil
        return GTCredentialProvider { (_, _, _) -> (GTCredential?) in
            var credential: GTCredential? = nil
            
            switch self.credential {
            case let .http(userName):
                var newPassword = Utils.getPasswordFromKeychain(name: "gitPassword")
                if newPassword == nil || attempts != 0 {
                    if let requestedPassword = requestGitPassword(self.credential, lastPassword) {
                        newPassword	= requestedPassword
                        Utils.addPasswordToKeychain(name: "gitPassword", password: newPassword)
                    } else {
                        return nil
                    }
                }
                attempts += 1
                lastPassword = newPassword
                credential = try? GTCredential(userName: userName, password: newPassword!)
            case let .ssh(userName, privateKeyFile):
                var newPassword = Utils.getPasswordFromKeychain(name: "gitSSHKeyPassphrase")
                if newPassword == nil || attempts != 0  {
                    if let requestedPassword = requestGitPassword(self.credential, lastPassword) {
                        newPassword	= requestedPassword
                        Utils.addPasswordToKeychain(name: "gitSSHKeyPassphrase", password: newPassword)
                    } else {
                        return nil
                    }
                }
                attempts += 1
                lastPassword = newPassword
                credential = try? GTCredential(userName: userName, publicKeyURL: nil, privateKeyURL: privateKeyFile, passphrase: newPassword!)
                print(privateKeyFile)
            }
            return credential
        }
    }
    
    public func delete() {
        switch credential {
        case .http:
            Utils.removeKeychain(name: "gitPassword")
        case .ssh:
            Utils.removeKeychain(name: "gitSSHKeyPassphrase")
        }
    }
}

