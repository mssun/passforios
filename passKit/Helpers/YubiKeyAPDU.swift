//
//  YubiKeyAPDU.swift
//  passKit
//
//  Copyright © 2022 Bob Sun. All rights reserved.
//

import YubiKit

public enum YubiKeyAPDU {
    public static func selectOpenPGPApplication() -> YKFSelectApplicationAPDU {
        YKFSelectApplicationAPDU(data: Data([0xD2, 0x76, 0x00, 0x01, 0x24, 0x01]))!
    }

    public static func verify(password: String) -> YKFAPDU {
        YKFAPDU(cla: 0x00, ins: 0x20, p1: 0x00, p2: 0x82, data: Data(password.utf8), type: .extended)!
    }

    public static func decipherExtended(data: Data) -> [YKFAPDU] {
        let apdu = YKFAPDU(cla: 0x00, ins: 0x2A, p1: 0x80, p2: 0x86, data: data, type: .extended)!
        return [apdu]
    }

    public static func decipherChained(data: Data) -> [YKFAPDU] {
        var result: [YKFAPDU] = []
        let chunks = chunk(data: data)

        for chunk in chunks.dropLast() {
            var apdu: [UInt8] = []
            apdu += [0x10] // CLA (command is not the last command of a chain)
            apdu += [0x2A, 0x80, 0x86] // INS, P1, P2: PSO.DECIPHER
            apdu += withUnsafeBytes(of: UInt8(chunk.count).bigEndian, Array.init)
            apdu += chunk
            result += [YKFAPDU(data: Data(apdu))!]
        }

        var apdu: [UInt8] = []
        apdu += [0x00] // CLA (last or only command of a chain)
        apdu += [0x2A, 0x80, 0x86] // INS, P1, P2: PSO.DECIPHER
        apdu += withUnsafeBytes(of: UInt8(chunks.last!.count).bigEndian, Array.init)
        apdu += chunks.last!
        apdu += [0x00] // Le
        result += [YKFAPDU(data: Data(apdu))!]

        return result
    }

    public static func getApplicationRelatedData() -> YKFAPDU {
        YKFAPDU(cla: 0x00, ins: 0xCA, p1: 0x00, p2: 0x6E, data: Data(), type: .short)!
    }

    static func chunk(data: Data) -> [[UInt8]] {
        // starts with 00 padding
        let padded: [UInt8] = [0x00] + data
        let MAX_SIZE = 254

        return stride(from: 0, to: padded.count, by: MAX_SIZE).map {
            Array(padded[$0 ..< Swift.min($0 + MAX_SIZE, padded.count)])
        }
    }
}
