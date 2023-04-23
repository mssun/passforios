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
        let pw1: [UInt8] = Array(password.utf8)
        var apdu: [UInt8] = []
        apdu += [0x00] // CLA
        apdu += [0x20] // INS: VERIFY
        apdu += [0x00] // P1
        apdu += [0x82] // P2: PW1
        apdu += withUnsafeBytes(of: UInt8(pw1.count).bigEndian, Array.init)
        apdu += pw1
        return YKFAPDU(data: Data(apdu))!
    }

    public static func decipherExtended(data: Data) -> [YKFAPDU] {
        var apdu: [UInt8] = []
        apdu += [0x00] // CLA (last or only command of a chain)
        apdu += [0x2A, 0x80, 0x86] // INS, P1, P2: PSO.DECIPHER
        // Lc, An extended Lc field consists of three bytes:
        // one byte set to '00' followed by two bytes not set to '0000' (1 to 65535 dec.).
        apdu += [0x00] + withUnsafeBytes(of: UInt16(data.count + 1).bigEndian, Array.init)
        // Padding indicator byte (00) for RSA or (02) for AES followed by cryptogram Cipher DO 'A6' for ECDH
        apdu += [0x00]
        apdu += data
        apdu += [0x02, 0x00]

        return [YKFAPDU(data: Data(apdu))!]
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

    public static func get_application_related_data() -> YKFAPDU {
        var apdu: [UInt8] = []
        apdu += [0x00] // CLA
        apdu += [0xCA] // INS: GET DATA
        apdu += [0x00]
        apdu += [0x6E] // P2: application related data
        apdu += [0x00]
        return YKFAPDU(data: Data(apdu))!
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
