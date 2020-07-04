//
//  SecurePasteboard.swift
//  pass
//
//  Created by Yishi Lin on 2017/7/27.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import UIKit

public class SecurePasteboard {
    public static let shared = SecurePasteboard()

    private var backgroundTaskID = UIBackgroundTaskIdentifier.invalid

    func copy(textToCopy: String?, expirationTime: Double = 45) {
        // copy to the pasteboard
        UIPasteboard.general.string = textToCopy ?? ""

        // clean the pasteboard after expirationTime
        guard expirationTime > 0 else {
            return
        }

        // exit the existing background task, if any
        if backgroundTaskID != UIBackgroundTaskIdentifier.invalid {
            UIApplication.shared.endBackgroundTask(UIBackgroundTaskIdentifier.invalid)
            backgroundTaskID = UIBackgroundTaskIdentifier.invalid
        }

        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            UIPasteboard.general.string = ""
            UIApplication.shared.endBackgroundTask(UIBackgroundTaskIdentifier.invalid)
            self?.backgroundTaskID = UIBackgroundTaskIdentifier.invalid
        }

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + expirationTime) { [weak self] in
            UIPasteboard.general.string = ""
            UIApplication.shared.endBackgroundTask(UIBackgroundTaskIdentifier.invalid)
            self?.backgroundTaskID = UIBackgroundTaskIdentifier.invalid
        }
    }
}
