//
//  AppError.swift
//  pass
//
//  Created by Mingshen Sun on 30/4/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

public enum AppError: Error {
    case RepositoryNotSet
    case RepositoryRemoteBranchNotFound(_: String)
    case RepositoryBranchNotFound(_: String)
    case KeyImport
    case PasswordDuplicated
    case GitReset
    case GitCommit
    case PasswordEntity
    case PgpPublicKeyNotExist
    case WrongPasswordFilename
    case Decryption
    case Encryption
    case Unknown
}

extension AppError: LocalizedError {
    public var errorDescription: String? {
        let localizationKey = "\(String(describing: self).prefix(while: { $0 != "(" }))Error."
        switch self {
        case let .RepositoryRemoteBranchNotFound(name), let .RepositoryBranchNotFound(name):
            return localizationKey.localize(name)
        default:
            return localizationKey.localize()
        }
    }
}
