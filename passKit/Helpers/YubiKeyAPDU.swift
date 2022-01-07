//
//  YubiKeyAPDU.swift
//  passKit
//
//  Copyright © 2022 Bob Sun. All rights reserved.
//

import YubiKit

public enum YubiKeyAPDU {
    public static func selectOpenPGPApplication() -> YKFSelectApplicationAPDU {
        let selectOpenPGPAPDU = YKFSelectApplicationAPDU(data: Data([0xD2, 0x76, 0x00, 0x01, 0x24, 0x01]))!
        return selectOpenPGPAPDU
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
        let verifyApdu = YKFAPDU(data: Data(apdu))!
        return verifyApdu
    }

    public static func decipher(data: Data) -> YKFAPDU {
        var apdu: [UInt8] = []
        apdu += [0x00] // CLA
        apdu += [0x2A, 0x80, 0x86] // INS, P1, P2: PSO.DECIPHER
        // Lc, An extended Lc field consists of three bytes:
        // one byte set to '00' followed by two bytes not set to '0000' (1 to 65535 dec.).
        apdu += [0x00] + withUnsafeBytes(of: UInt16(data.count + 1).bigEndian, Array.init)
        // Padding indicator byte (00) for RSA or (02) for AES followed by cryptogram Cipher DO 'A6' for ECDH
        apdu += [0x00]
        apdu += data
        apdu += [0x02, 0x00]
        let decipherApdu = YKFAPDU(data: Data(apdu))!

        return decipherApdu
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
}
