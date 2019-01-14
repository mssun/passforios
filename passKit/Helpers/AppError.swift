//
//  AppError.swift
//  pass
//
//  Created by Mingshen Sun on 30/4/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation

public enum AppError: Error {
    case RepositoryNotSetError
    case RepositoryRemoteBranchNotFoundError(_: String)
    case RepositoryBranchNotFound(_: String)
    case KeyImportError
    case PasswordDuplicatedError
    case GitResetError
    case PGPPublicKeyNotExistError
    case WrongPasswordFilename
    case DecryptionError
    case UnknownError
}

extension AppError: LocalizedError {
    public var errorDescription: String? {
        return String(describing: self).localize()
    }
}
