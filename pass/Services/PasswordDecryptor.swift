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

class PasswordYubiKeyDecryptor {
    let yubiKeyConnection = YubiKeyConnection()

    func didDisconnect(completion: @escaping (_ connection: YKFConnectionProtocol?, _ error: Error?) -> Void) {
        yubiKeyConnection.didDisconnect(handler: completion)
    }

    private func handleError(error: Error, forConnection connection: YKFConnectionProtocol) -> Error {
        if (connection as? YKFNFCConnection) != nil {
            YubiKitManager.shared.stopNFCConnection(withErrorMessage: error.localizedDescription)
            return error // Dont pass on the error since we display it in the NFC modal
        }
        return error
    }

    func yubiKeyDecrypt(encryptedData: Data, pin: String) async throws -> Data {
        let connection = await yubiKeyConnection.startConnection()

        do {
            guard let smartCard = connection.smartCardInterface else {
                throw AppError.yubiKey(.connection(message: "Failed to get smart card interface."))
            }
            do {
                try await smartCard.selectOpenPGPApplication()
            } catch {
                throw AppError.yubiKey(.connection(message: "Failed to select OpenPGP application"))
            }
            do {
                try await smartCard.verify(password: pin)
            } catch {
                throw AppError.yubiKey(.connection(message: "Failed to verify PIN"))
            }
            guard let deciphered = try? await smartCard.decipher(ciphertext: encryptedData) else {
                throw AppError.yubiKey(.connection(message: "Failed to decipher data"))
            }
            let decryptedData = try decryptData(deciphered: deciphered, ciphertext: encryptedData)
            if (connection as? YKFNFCConnection) != nil {
                YubiKitManager.shared.stopNFCConnection()
            }
            return decryptedData
        } catch {
            throw handleError(error: error, forConnection: connection)
        }
    }
}

private func decryptData(deciphered: Data, ciphertext: Data) throws -> Data {
    let symmetricKeyIDNameDict: [UInt8: String] = [
        2: "3des",
        3: "cast5",
        7: "aes128",
        8: "aes192",
        9: "aes256",
    ]

    let message = createPGPMessage(from: ciphertext)

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

    return plaintext
}
