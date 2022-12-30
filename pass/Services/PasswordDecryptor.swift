//
//  PasswordDecryptor.swift
//  pass
//
//  Created by Sun, Mingshen on 1/17/21.
//  Copyright © 2021 Bob Sun. All rights reserved.
//

import CryptoTokenKit
import Gopenpgp
import passKit
import SVProgressHUD
import UIKit
import YubiKit

func decryptPassword(
    in controller: UIViewController,
    with passwordPath: String,
    using keyID: String? = nil,
    completion: @escaping ((Password) -> Void)
) {
    // YubiKey is not supported in extension
    if Defaults.isYubiKeyEnabled {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Error", message: "YubiKey is not supported in extension, please use the Pass app instead.", preferredStyle: .alert)
            alert.addAction(UIAlertAction.ok())
            controller.present(alert, animated: true)
        }
        return
    }
    DispatchQueue.global(qos: .userInteractive).async {
        do {
            let requestPGPKeyPassphrase = Utils.createRequestPGPKeyPassphraseHandler(controller: controller)
            let decryptedPassword = try PasswordStore.shared.decrypt(path: passwordPath, keyID: keyID, requestPGPKeyPassphrase: requestPGPKeyPassphrase)

            DispatchQueue.main.async {
                completion(decryptedPassword)
            }
        } catch let AppError.pgpPrivateKeyNotFound(keyID: key) {
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "CannotShowPassword".localize(), message: AppError.pgpPrivateKeyNotFound(keyID: key).localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction.cancelAndPopView(controller: controller))
                let selectKey = UIAlertAction.selectKey(controller: controller) { action in
                    decryptPassword(in: controller, with: passwordPath, using: action.title, completion: completion)
                }
                alert.addAction(selectKey)

                controller.present(alert, animated: true)
            }
        } catch {
            DispatchQueue.main.async {
                Utils.alert(title: "CannotCopyPassword".localize(), message: error.localizedDescription, controller: controller)
            }
        }
    }
}

public typealias RequestPINAction = (@escaping (String) -> Void, @escaping () -> Void) -> Void

let symmetricKeyIDNameDict: [UInt8: String] = [
    2: "3des",
    3: "cast5",
    7: "aes128",
    8: "aes192",
    9: "aes256",
]

private func isEncryptKeyAlgoRSA(_ applicationRelatedData: Data) -> Bool {
    let tlv = TKBERTLVRecord.sequenceOfRecords(from: applicationRelatedData)!
    // 0x73: Discretionary data objects
    for record in TKBERTLVRecord.sequenceOfRecords(from: tlv.first!.value)! where record.tag == 0x73 {
        // 0xC2: Algorithm attributes decryption, 0x01: RSA
        for record2 in TKBERTLVRecord.sequenceOfRecords(from: record.value)! where record2.tag == 0xC2 && record2.value.first! == 0x01 {
            return true
        }
    }
    return false
}

private func getCapabilities(_ applicationRelatedData: Data) -> (Bool, Bool) {
    let tlv = TKBERTLVRecord.sequenceOfRecords(from: applicationRelatedData)!
    // 0x5f52: Historical Bytes
    for record in TKBERTLVRecord.sequenceOfRecords(from: tlv.first!.value)! where record.tag == 0x5F52 {
        let historical = record.value
        if historical.count < 4 {
            // log_error ("warning: historical bytes are too short\n");
            return (false, false)
        }

        if historical[0] != 0 {
            // log_error ("warning: bad category indicator in historical bytes\n");
            return (false, false)
        }

        let dos = historical[1 ..< historical.endIndex - 3]
        for record2 in TKCompactTLVRecord.sequenceOfRecords(from: dos)! where record2.tag == 7 && record2.value.count == 3 {
            let cmd_chaining = (record2.value[2] & 0x80) != 0
            let ext_lc_le = (record2.value[2] & 0x40) != 0
            return (cmd_chaining, ext_lc_le)
        }
    }
    return (false, false)
}

public func yubiKeyDecrypt(
    passwordEntity: PasswordEntity,
    requestPIN: @escaping RequestPINAction,
    errorHandler: @escaping ((AppError) -> Void),
    cancellation: @escaping (() -> Void),
    completion: @escaping ((Password) -> Void)
) {
    Task {
        do {
            let encryptedDataPath = PasswordStore.shared.storeURL.appendingPathComponent(passwordEntity.getPath())

            guard let encryptedData = try? Data(contentsOf: encryptedDataPath) else {
                errorHandler(AppError.other(message: "PasswordDoesNotExist".localize()))
                return
            }

            guard let pin = await readPin(requestPIN: requestPIN) else {
                return
            }

            guard let connection = try? await getConnection() else {
                cancellation()
                return
            }

            guard let smartCard = connection.smartCardInterface else {
                throw AppError.yubiKey(.connection(message: "Failed to get smart card interface."))
            }

            try await selectOpenPGPApplication(smartCard: smartCard)

            try await verifyPin(smartCard: smartCard, pin: pin)

            guard let applicationRelatedData = try await getApplicationRelatedData(smartCard: smartCard) else {
                throw AppError.yubiKey(.decipher(message: "Failed to get application related data."))
            }

            if !isEncryptKeyAlgoRSA(applicationRelatedData) {
                throw AppError.yubiKey(.decipher(message: "Encryption key algorithm is not supported. Supported algorithm: RSA."))
            }

            let (cmd_chaining, _) = getCapabilities(applicationRelatedData)

            let deciphered = try await decipher(smartCard: smartCard, ciphertext: encryptedData, chained: cmd_chaining)

            YubiKitManager.shared.stopNFCConnection()

            let plaintext = try decryptPassword(deciphered: deciphered, ciphertext: encryptedData)
            guard let password = try? Password(name: passwordEntity.getName(), url: passwordEntity.getURL(), plainText: plaintext) else {
                throw AppError.yubiKey(.decipher(message: "Failed to construct password."))
            }

            completion(password)
        } catch let error as AppError {
            errorHandler(error)
        } catch {
            errorHandler(AppError.other(message: String(describing: error)))
        }
    }
}

func readPin(requestPIN: @escaping RequestPINAction) async -> String? {
    await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
        DispatchQueue.main.async {
            requestPIN({ pin in continuation.resume(returning: pin) }, { continuation.resume(returning: nil) })
        }
    }
}

func getConnection() async throws -> YKFConnectionProtocol? {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<YKFConnectionProtocol?, Error>) in
        passKit.YubiKeyConnection.shared.connection(cancellation: { error in
            continuation.resume(throwing: error)
        }, completion: { connection in
            continuation.resume(returning: connection)
        })
    }
}

func selectOpenPGPApplication(smartCard: YKFSmartCardInterface) async throws {
    if await withCheckedContinuation({ (continuation: CheckedContinuation<Error?, Never>) in
        smartCard.selectApplication(YubiKeyAPDU.selectOpenPGPApplication()) { _, error in
            continuation.resume(returning: error)
        }
    }) != nil {
        throw AppError.yubiKey(.selectApplication(message: "Failed to select application."))
    }
}

func getApplicationRelatedData(smartCard: YKFSmartCardInterface) async throws -> Data? {
    try await executeCommandAsync(smartCard: smartCard, apdu: YubiKeyAPDU.get_application_related_data())
}

func verifyPin(smartCard: YKFSmartCardInterface, pin: String) async throws {
    if await withCheckedContinuation({ (continuation: CheckedContinuation<Error?, Never>) in
        smartCard.executeCommand(YubiKeyAPDU.verify(password: pin)) { _, error in
            continuation.resume(returning: error)
        }}) != nil {
        throw AppError.yubiKey(.selectApplication(message: "Failed to verify PIN."))
    }
}

func decipher(smartCard: YKFSmartCardInterface, ciphertext: Data, chained: Bool) async throws -> Data {
    var error: NSError?
    let message = CryptoNewPGPMessage(ciphertext)
    guard let mpi1 = Gopenpgp.HelperPassGetEncryptedMPI1(message, &error) else {
        throw AppError.yubiKey(.decipher(message: "Failed to get encrypted MPI."))
    }

    let apdus = chained ? YubiKeyAPDU.decipherChained(data: mpi1) : YubiKeyAPDU.decipherExtended(data: mpi1)

    for (idx, apdu) in apdus.enumerated() {
        let data = try await executeCommandAsync(smartCard: smartCard, apdu: apdu)
        // the last response must have the data
        if idx == apdus.endIndex - 1, let data {
            return data
        }
    }

    throw AppError.yubiKey(.verify(message: "Failed to execute decipher."))
}

func decryptPassword(deciphered: Data, ciphertext: Data) throws -> String {
    let message = CryptoNewPGPMessage(ciphertext)

    guard let algoByte = deciphered.first, let algo = symmetricKeyIDNameDict[algoByte] else {
        throw AppError.yubiKey(.decipher(message: "Failed to new session key."))
    }

    guard let session_key = Gopenpgp.CryptoNewSessionKeyFromToken(deciphered[1 ..< deciphered.count - 2], algo) else {
        throw AppError.yubiKey(.decipher(message: "Failed to new session key."))
    }

    var error: NSError?
    guard let plaintext = Gopenpgp.HelperPassDecryptWithSessionKey(message, session_key, &error)?.data else {
        throw AppError.yubiKey(.decipher(message: "Failed to decrypt with session key: \(String(describing: error))"))
    }

    guard let plaintext_str = String(data: plaintext, encoding: .utf8) else {
        throw AppError.yubiKey(.decipher(message: "Failed to convert plaintext to string."))
    }

    return plaintext_str
}

func executeCommandAsync(smartCard: YKFSmartCardInterface, apdu: YKFAPDU) async throws -> Data? {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data?, Error>) in
        smartCard.executeCommand(apdu) { data, error in
            if let error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: data)
            }
        }
    }
}

extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = Self(rawValue: 1 << 0)
    }

    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }
}
