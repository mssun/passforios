//
//  SecurePasteboard.swift
//  pass
//
//  Created by Yishi Lin on 2017/7/27.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import UIKit

class SecurePasteboard {
    public static let shared = SecurePasteboard()
    private var backgroundTaskID = UIBackgroundTaskInvalid
    
    func copy(textToCopy: String?, expirationTime: Double = 45) {
        // copy to the pasteboard
        UIPasteboard.general.string = textToCopy ?? ""
        
        // clean the pasteboard after expirationTime
        guard expirationTime > 0 else {
            return
        }
        
        // exit the existing background task, if any
        if backgroundTaskID != UIBackgroundTaskInvalid {
            UIApplication.shared.endBackgroundTask(UIBackgroundTaskInvalid)
            self.backgroundTaskID = UIBackgroundTaskInvalid
        }
        
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: { [weak self] in
            UIPasteboard.general.string = ""
            UIApplication.shared.endBackgroundTask(UIBackgroundTaskInvalid)
            self?.backgroundTaskID = UIBackgroundTaskInvalid
        })
        
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + expirationTime) { [weak self] in
            UIPasteboard.general.string = ""
            UIApplication.shared.endBackgroundTask(UIBackgroundTaskInvalid)
            self?.backgroundTaskID = UIBackgroundTaskInvalid
        }
    }
    
}
