//
//  YKFSmartCardInterfaceExtension.swift
//  pass
//
//  Created by Mingshen Sun on 12/15/24.
//  Copyright © 2024 Bob Sun. All rights reserved.
//

import CryptoTokenKit
import Gopenpgp
import YubiKit

public struct ApplicationRelatedData {
    public let isCommandChaining: Bool
}

public extension YKFSmartCardInterface {
    func selectOpenPGPApplication() async throws {
        try await selectApplication(YubiKeyAPDU.selectOpenPGPApplication())
    }

    func verify(password: String) async throws {
        try await executeCommand(YubiKeyAPDU.verify(password: password))
    }

    func getApplicationRelatedData() async throws -> ApplicationRelatedData {
        let data = try await executeCommand(YubiKeyAPDU.getApplicationRelatedData())
        var isCommandChaining = false
        let tlv = TKBERTLVRecord.sequenceOfRecords(from: data)!
        for record in TKBERTLVRecord.sequenceOfRecords(from: tlv.first!.value)! {
            if record.tag == 0x5F52 { // 0x5f52: Historical Bytes
                let historical = record.value
                if historical.count < 4 {
                    isCommandChaining = false
                }
                if historical[0] != 0 {
                    isCommandChaining = false
                }
                let dos = historical[1 ..< historical.endIndex - 3]
                for record2 in TKCompactTLVRecord.sequenceOfRecords(from: dos)! where record2.tag == 7 && record2.value.count == 3 {
                    isCommandChaining = (record2.value[2] & 0x80) != 0
                }
            }
        }
        return ApplicationRelatedData(isCommandChaining: isCommandChaining)
    }

    func decipher(ciphertext: Data) async throws -> Data {
        let applicationRelatedData = try await getApplicationRelatedData()

        var error: NSError?
        let message = createPGPMessage(from: ciphertext)
        guard let mpi1 = Gopenpgp.HelperPassGetEncryptedMPI1(message, &error) else {
            throw AppError.yubiKey(.decipher(message: "Failed to get encrypted MPI."))
        }

        let apdus = applicationRelatedData.isCommandChaining ? YubiKeyAPDU.decipherChained(data: mpi1) : YubiKeyAPDU.decipherExtended(data: mpi1)

        for (idx, apdu) in apdus.enumerated() {
            let data = try await executeCommand(apdu)
            // the last response must have the data
            if idx == apdus.endIndex - 1 {
                return data
            }
        }

        throw AppError.yubiKey(.verify(message: "Failed to execute decipher."))
    }
}
