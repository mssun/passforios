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

public typealias RequestPINAction = (@escaping (String) -> Void) -> Void

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

// swiftlint:disable cyclomatic_complexity
public func yubiKeyDecrypt(
    passwordEntity: PasswordEntity,
    requestPIN: @escaping RequestPINAction,
    errorHandler: @escaping ((AppError) -> Void),
    cancellation: @escaping ((_ error: Error) -> Void),
    completion: @escaping ((Password) -> Void)
) {
    let encryptedDataPath = PasswordStore.shared.storeURL.appendingPathComponent(passwordEntity.getPath())

    guard let encryptedData = try? Data(contentsOf: encryptedDataPath) else {
        errorHandler(AppError.other(message: "PasswordDoesNotExist".localize()))
        return
    }

    // swiftlint:disable closure_body_length
    requestPIN { pin in
        // swiftlint:disable closure_body_length
        passKit.YubiKeyConnection.shared.connection(cancellation: cancellation) { connection in
            guard let smartCard = connection.smartCardInterface else {
                errorHandler(AppError.yubiKey(.connection(message: "Failed to get smart card interface.")))
                return
            }

            // 1. Select OpenPGP application
            let selectOpenPGPAPDU = YubiKeyAPDU.selectOpenPGPApplication()
            smartCard.selectApplication(selectOpenPGPAPDU) { _, error in
                guard error == nil else {
                    errorHandler(AppError.yubiKey(.selectApplication(message: "Failed to select application.")))
                    return
                }

                // 2. Verify PIN
                let verifyApdu = YubiKeyAPDU.verify(password: pin)
                smartCard.executeCommand(verifyApdu) { _, error in
                    guard error == nil else {
                        errorHandler(AppError.yubiKey(.verify(message: "Failed to verify PIN.")))
                        return
                    }

                    let applicationRelatedDataApdu = YubiKeyAPDU.get_application_related_data()
                    smartCard.executeCommand(applicationRelatedDataApdu) { data, _ in
                        guard let data = data else {
                            errorHandler(AppError.yubiKey(.decipher(message: "Failed to get application related data.")))
                            return
                        }

                        if !isEncryptKeyAlgoRSA(data) {
                            errorHandler(AppError.yubiKey(.decipher(message: "Encryption key algorithm is not supported. Supported algorithm: RSA.")))
                            return
                        }

                        // 3. Decipher
                        let ciphertext = encryptedData
                        var error: NSError?
                        let message = CryptoNewPGPMessage(ciphertext)
                        guard let mpi1 = Gopenpgp.HelperPassGetEncryptedMPI1(message, &error) else {
                            errorHandler(AppError.yubiKey(.decipher(message: "Failed to get encrypted MPI.")))
                            return
                        }

                        let decipherApdu = YubiKeyAPDU.decipher(data: mpi1)
                        smartCard.executeCommand(decipherApdu) { data, error in
                            guard let data = data else {
                                errorHandler(AppError.yubiKey(.decipher(message: "Failed to execute decipher.")))
                                return
                            }

                            if #available(iOS 13.0, *) {
                                YubiKitManager.shared.stopNFCConnection()
                            }
                            guard let algoByte = data.first, let algo = symmetricKeyIDNameDict[algoByte] else {
                                errorHandler(AppError.yubiKey(.decipher(message: "Failed to new session key.")))
                                return
                            }
                            guard let session_key = Gopenpgp.CryptoNewSessionKeyFromToken(data[1 ..< data.count - 2], algo) else {
                                errorHandler(AppError.yubiKey(.decipher(message: "Failed to new session key.")))
                                return
                            }

                            var error: NSError?
                            let message = CryptoNewPGPMessage(ciphertext)

                            guard let plaintext = Gopenpgp.HelperPassDecryptWithSessionKey(message, session_key, &error)?.data else {
                                errorHandler(AppError.yubiKey(.decipher(message: "Failed to decrypt with session key.")))
                                return
                            }

                            guard let plaintext_str = String(data: plaintext, encoding: .utf8) else {
                                errorHandler(AppError.yubiKey(.decipher(message: "Failed to convert plaintext to string.")))
                                return
                            }

                            guard let password = try? Password(name: passwordEntity.getName(), url: passwordEntity.getURL(), plainText: plaintext_str) else {
                                errorHandler(AppError.yubiKey(.decipher(message: "Failed to construct password.")))
                                return
                            }

                            completion(password)
                        }
                    }
                }
            }
        }
    }
}

extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }

    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }
}
