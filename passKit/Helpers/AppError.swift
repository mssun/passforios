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
        switch self {
        case .RepositoryNotSetError:
            return "Git repository is not set."
        case let .RepositoryRemoteBranchNotFoundError(remoteBranchName):
            return "Cannot find remote branch 'origin/\(remoteBranchName)'."
        case let .RepositoryBranchNotFound(branchName):
            return "Branch with name '\(branchName)' not found in repository."
        case .KeyImportError:
            return "Cannot import the key."
        case .PasswordDuplicatedError:
            return "Cannot add the password: password duplicated."
        case .GitResetError:
            return "Cannot identify the latest synced commit."
        case .PGPPublicKeyNotExistError:
            return "PGP public key doesn't exist."
        case .WrongPasswordFilename:
            return "Cannot write to the password file."
        case .DecryptionError:
            return "Cannot decrypt password."
        case .UnknownError:
            return "Unknown error."
        }
    }
}
