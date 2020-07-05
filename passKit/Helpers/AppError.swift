//
//  AppError.swift
//  pass
//
//  Created by Mingshen Sun on 30/4/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

public enum AppError: Error, Equatable {
    case RepositoryNotSet
    case RepositoryRemoteBranchNotFound(_: String)
    case RepositoryBranchNotFound(_: String)
    case KeyImport
    case ReadingFile(_: String)
    case PasswordDuplicated
    case GitReset
    case GitCreateSignature
    case GitPushNotSuccessful
    case PasswordEntity
    case PgpPublicKeyNotFound(keyID: String)
    case PgpPrivateKeyNotFound(keyID: String)
    case KeyExpiredOrIncompatible
    case WrongPassphrase
    case WrongPasswordFilename
    case Decryption
    case Encryption
    case Encoding
    case Unknown
}

extension AppError: LocalizedError {
    public var errorDescription: String? {
        let localizationKey = "\(String(describing: self).prefix { $0 != "(" })Error."
        switch self {
        case let .RepositoryRemoteBranchNotFound(name), let .RepositoryBranchNotFound(name), let .ReadingFile(name):
            return localizationKey.localize(name)
        case let .PgpPublicKeyNotFound(keyID), let .PgpPrivateKeyNotFound(keyID):
            return localizationKey.localize(keyID)
        default:
            return localizationKey.localize()
        }
    }
}
