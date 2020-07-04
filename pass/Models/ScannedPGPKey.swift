//
//  ScannedPGPKey.swift
//  pass
//
//  Created by Danny Moesch on 05.07.20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

class ScannedPGPKey {
    enum KeyType {
        case publicKey, privateKey
    }

    var keyType = KeyType.publicKey
    var segments = [String]()
    var message = ""

    func reset(keytype: KeyType) {
        keyType = keytype
        segments.removeAll()
        message = "LookingForStartingFrame.".localize()
    }

    func addSegment(segment: String) -> (accept: Bool, message: String) {
        let keyTypeStr = keyType == .publicKey ? "Public" : "Private"
        let theOtherKeyTypeStr = keyType == .publicKey ? "Private" : "Public"

        // Skip duplicated segments.
        guard segment != segments.last else {
            return (accept: false, message: message)
        }

        // Check whether we have found the first block.
        guard !segments.isEmpty || segment.contains("-----BEGIN PGP \(keyTypeStr.uppercased()) KEY BLOCK-----") else {
            // Check whether we are scanning the wrong key type.
            if segment.contains("-----BEGIN PGP \(theOtherKeyTypeStr.uppercased()) KEY BLOCK-----") {
                message = "Scan\(keyTypeStr)Key.".localize()
            }
            return (accept: false, message: message)
        }

        // Update the list of scanned segment and return.
        segments.append(segment)
        if segment.contains("-----END PGP \(keyTypeStr.uppercased()) KEY BLOCK-----") {
            message = "Done".localize()
            return (accept: true, message: message)
        } else {
            message = "ScannedQrCodes(%d)".localize(segments.count)
            return (accept: false, message: message)
        }
    }
}
