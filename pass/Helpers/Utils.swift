//
//  Utils.swift
//  pass
//
//  Created by Mingshen Sun on 8/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import SwiftyUserDefaults

class Utils {
    static func removeFileIfExists(atPath path: String) {
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: path) {
                try fm.removeItem(atPath: path)
            }
        } catch {
            print(error)
        }
    }
    static func removeFileIfExists(at url: URL) {
        removeFileIfExists(atPath: url.path)
    }
    
    static func getLastUpdatedTimeString() -> String {
        var lastUpdatedTimeString = ""
        if let lastUpdatedTime = Defaults[.lastUpdatedTime] {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .short
            lastUpdatedTimeString = formatter.string(from: lastUpdatedTime)
        }
        return lastUpdatedTimeString
    }
}
