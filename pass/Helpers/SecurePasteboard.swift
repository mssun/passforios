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
    private var backgroundTaskID: UIBackgroundTaskIdentifier? = nil
    
    func copy(textToCopy: String?, expirationTime: Double = 45) {
        // copy to the pasteboard
        UIPasteboard.general.string = textToCopy ?? ""
        
        // clean the pasteboard after expirationTime
        guard expirationTime > 0 else {
            return
        }
        
        // exit the existing background task, if any
        if let backgroundTaskID = backgroundTaskID {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            self.backgroundTaskID = nil
        }
        
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(expirationHandler: { [weak self] in
            guard let taskID = self?.backgroundTaskID else {
                return
            }
            if textToCopy == UIPasteboard.general.string {
                UIPasteboard.general.string = ""
            }
            UIApplication.shared.endBackgroundTask(taskID)
        })
        
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + expirationTime) { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if textToCopy == UIPasteboard.general.string {
                UIPasteboard.general.string = ""
            }
            if let backgroundTaskID = strongSelf.backgroundTaskID {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                strongSelf.backgroundTaskID = nil
            }
        }
    }
    
}
