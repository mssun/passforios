//
//  YubiKeyConnection.swift
//  passKit
//
//  Copyright © 2022 Bob Sun. All rights reserved.
//

import Foundation
import YubiKit

public class YubiKeyConnection: NSObject {
    public static let shared = YubiKeyConnection()

    var accessoryConnection: YKFAccessoryConnection?
    var nfcConnection: YKFNFCConnection?
    var connectionCallback: ((_ connection: YKFConnectionProtocol) -> Void)?

    override init() {
        super.init()
        YubiKitManager.shared.delegate = self
        YubiKitManager.shared.startAccessoryConnection()
    }

    public func connection(completion: @escaping (_ connection: YKFConnectionProtocol) -> Void) {
        if let connection = accessoryConnection {
            completion(connection)
        } else {
            connectionCallback = completion
            if #available(iOSApplicationExtension 13.0, *) {
                YubiKitManager.shared.startNFCConnection()
            }
        }
    }
}

extension YubiKeyConnection: YKFManagerDelegate {
    public func didConnectNFC(_ connection: YKFNFCConnection) {
        nfcConnection = connection
        if let callback = connectionCallback {
            callback(connection)
        }
    }

    public func didDisconnectNFC(_: YKFNFCConnection, error _: Error?) {
        nfcConnection = nil
    }

    public func didConnectAccessory(_ connection: YKFAccessoryConnection) {
        accessoryConnection = connection
    }

    public func didDisconnectAccessory(_: YKFAccessoryConnection, error _: Error?) {
        accessoryConnection = nil
    }
}
