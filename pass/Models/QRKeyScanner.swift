//
//  QRKeyScanner.swift
//  pass
//
//  Created by Danny Moesch on 19.08.20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

struct QRKeyScanner {
    enum Result: Equatable {
        case lookingForStart
        case wrongKeyType(ScannableKeyType)
        case completed
        case scanned(Int)

        var message: String {
            switch self {
            case .lookingForStart:
                return "LookingForStartingFrame.".localize()
            case let .wrongKeyType(keyType):
                return "Scan\(keyType.visibility)Key.".localize()
            case .completed:
                return "Done".localize()
            case let .scanned(count):
                return "ScannedQrCodes(%d)".localize(count)
            }
        }

        var unrolled: (accepted: Bool, message: String) {
            if self == .completed {
                return (true, message)
            }
            return (false, message)
        }
    }

    private var segments = [String]()
    private var previousResult = Result.lookingForStart

    let keyType: ScannableKeyType

    init(keyType: ScannableKeyType) {
        self.keyType = keyType
    }

    var scannedKey: String {
        segments.joined()
    }

    mutating func add(segment: String) -> Result {
        // Skip duplicated segments.
        guard segment != segments.last else {
            return previousResult
        }

        // Check whether we have found the first block.
        guard !segments.isEmpty || segment.contains(keyType.headerStart) else {
            // Check whether we are scanning the wrong key type.
            if let counterKeyType = keyType.counterType, segment.contains(counterKeyType.headerStart) {
                previousResult = .wrongKeyType(counterKeyType)
            }
            return previousResult
        }

        // Update the list of scanned segments and return.
        segments.append(segment)
        if segment.starts(with: keyType.footerStart), segment.hasSuffix(keyType.footerEnd) {
            return .completed
        }
        previousResult = .scanned(segments.count)
        return previousResult
    }
}
