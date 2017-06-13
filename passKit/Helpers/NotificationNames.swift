//
//  NotificationNames.swift
//  pass
//
//  Created by Yishi Lin on 17/3/17.
//  Copyright © 2017 Yishi Lin, Bob Sun. All rights reserved.
//

import Foundation

public extension Notification.Name {
    static let passwordStoreUpdated = Notification.Name("passwordStoreUpdated")
    static let passwordStoreErased = Notification.Name("passwordStoreErased")
    static let passwordStoreChangeDiscarded = Notification.Name("passwordStoreChangeDiscarded")
    static let passwordSearch = Notification.Name("passwordSearch")
    
    static let passwordDisplaySettingChanged = Notification.Name("passwordDisplaySettingChanged")
    static let passwordDetailDisplaySettingChanged = Notification.Name("passwordDetailDisplaySettingChanged")
}
