//
//  AppError.swift
//  passKit
//
//  Created by Mingshen Sun on 30/4/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

public enum AppError: Error, Equatable {
    case repositoryNotSet
    case repositoryRemoteBranchNotFound(branchName: String)
    case repositoryBranchNotFound(branchName: String)
    case keyImport
    case readingFile(fileName: String)
    case passwordDuplicated
    case gitReset
    case gitCreateSignature
    case gitPushNotSuccessful
    case pgpPublicKeyNotFound(keyID: String)
    case pgpPrivateKeyNotFound(keyID: String)
    case keyExpiredOrIncompatible
    case wrongPassphrase
    case wrongPasswordFilename
    case decryption
    case encryption
    case encoding
    case unknown
}

extension AppError: LocalizedError {
    public var errorDescription: String? {
        let enumName = String(describing: self)
        let localizationKey = "\(enumName.first!.uppercased())\(enumName.dropFirst().prefix { $0 != "(" })Error."
        switch self {
        case let .readingFile(name), let .repositoryBranchNotFound(name), let .repositoryRemoteBranchNotFound(name):
            return localizationKey.localize(name)
        case let .pgpPrivateKeyNotFound(keyID), let .pgpPublicKeyNotFound(keyID):
            return localizationKey.localize(keyID)
        default:
            return localizationKey.localize()
        }
    }
}
