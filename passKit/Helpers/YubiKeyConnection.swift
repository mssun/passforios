//
//  YubiKeyConnection.swift
//  passKit
//
//  Copyright (C) 2024 Mingshen Sun.
//
//  This file is part of yubioath-ios, modified from the original.
//  Original code Copyright Yubico 2022.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import YubiKit

public class YubiKeyConnection: NSObject {
    override public init() {
        super.init()
        YubiKitManager.shared.delegate = self
    }

    deinit {}

    var connection: YKFConnectionProtocol? {
        accessoryConnection ?? smartCardConnection ?? nfcConnection
    }

    private var nfcConnection: YKFNFCConnection?
    private var smartCardConnection: YKFSmartCardConnection?
    private var accessoryConnection: YKFAccessoryConnection?

    private var connectionCallback: ((_ connection: YKFConnectionProtocol) -> Void)?
    private var disconnectionCallback: ((_ connection: YKFConnectionProtocol?, _ error: Error?) -> Void)?

    private var accessoryConnectionCallback: ((_ connection: YKFAccessoryConnection?) -> Void)?
    private var nfcConnectionCallback: ((_ connection: YKFNFCConnection?) -> Void)?
    private var smartCardConnectionCallback: ((_ connection: YKFSmartCardConnection?) -> Void)?

    public func startConnection(completion: @escaping (_ connection: YKFConnectionProtocol) -> Void) {
        YubiKitManager.shared.delegate = self

        if let connection = accessoryConnection {
            completion(connection)
        } else if let connection = smartCardConnection {
            completion(connection)
        } else if let connection = nfcConnection {
            completion(connection)
        } else {
            connectionCallback = completion
            if YubiKitDeviceCapabilities.supportsISO7816NFCTags {
                YubiKitManager.shared.startNFCConnection()
            }
        }
    }

    public func startConnection() async -> YKFConnectionProtocol {
        await withCheckedContinuation { continuation in
            self.startConnection { connection in
                continuation.resume(with: Result.success(connection))
            }
        }
    }

    func startWiredConnection(completion: @escaping (_ connection: YKFConnectionProtocol) -> Void) {
        connectionCallback = completion
        YubiKitManager.shared.delegate = self
    }

    func accessoryConnection(handler: @escaping (_ connection: YKFAccessoryConnection?) -> Void) {
        if let connection = accessoryConnection {
            handler(connection)
        } else {
            accessoryConnectionCallback = handler
        }
    }

    func smartCardConnection(handler: @escaping (_ connection: YKFSmartCardConnection?) -> Void) {
        if let connection = smartCardConnection {
            handler(connection)
        } else {
            smartCardConnectionCallback = handler
        }
    }

    func nfcConnection(handler: @escaping (_ connection: YKFNFCConnection?) -> Void) {
        if let connection = nfcConnection {
            handler(connection)
        } else {
            nfcConnectionCallback = handler
        }
    }

    public func stop() {
        if #available(iOSApplicationExtension 16.0, *) {
            smartCardConnection?.stop()
        }
        accessoryConnection?.stop()
        nfcConnection?.stop()
        // stop() returns immediately but closing the connection will take a few cycles so we need to wait to make sure it's closed before restarting.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if YubiKitDeviceCapabilities.supportsMFIAccessoryKey {
                YubiKitManager.shared.startAccessoryConnection()
            }
            if YubiKitDeviceCapabilities.supportsSmartCardOverUSBC, #available(iOSApplicationExtension 16.0, *) {
                YubiKitManager.shared.startSmartCardConnection()
            }
        }
    }

    public func didDisconnect(handler: @escaping (_ connection: YKFConnectionProtocol?, _ error: Error?) -> Void) {
        disconnectionCallback = handler
    }
}

extension YubiKeyConnection: YKFManagerDelegate {
    public func didConnectNFC(_ connection: YKFNFCConnection) {
        nfcConnection = connection
        nfcConnectionCallback?(connection)
        nfcConnectionCallback = nil
        connectionCallback?(connection)
        connectionCallback = nil
    }

    public func didDisconnectNFC(_ connection: YKFNFCConnection, error: Error?) {
        nfcConnection = nil
        nfcConnectionCallback = nil
        connectionCallback = nil
        disconnectionCallback?(connection, error)
        disconnectionCallback = nil
    }

    public func didFailConnectingNFC(_ error: Error) {
        nfcConnectionCallback = nil
        connectionCallback = nil
        disconnectionCallback?(nil, error)
        disconnectionCallback = nil
    }

    public func didConnectAccessory(_ connection: YKFAccessoryConnection) {
        accessoryConnection = connection
        accessoryConnectionCallback?(connection)
        accessoryConnectionCallback = nil
        connectionCallback?(connection)
        connectionCallback = nil
    }

    public func didDisconnectAccessory(_ connection: YKFAccessoryConnection, error: Error?) {
        accessoryConnection = nil
        accessoryConnectionCallback = nil
        connectionCallback = nil
        disconnectionCallback?(connection, error)
        disconnectionCallback = nil
    }

    public func didConnectSmartCard(_ connection: YKFSmartCardConnection) {
        smartCardConnection = connection
        smartCardConnectionCallback?(connection)
        smartCardConnectionCallback = nil
        connectionCallback?(connection)
        connectionCallback = nil
    }

    public func didDisconnectSmartCard(_ connection: YKFSmartCardConnection, error: Error?) {
        smartCardConnection = nil
        smartCardConnectionCallback = nil
        connectionCallback = nil
        disconnectionCallback?(connection, error)
        disconnectionCallback = nil
    }
}
