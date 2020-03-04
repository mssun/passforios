//
//  IntentHandler.swift
//  passShortcuts
//
//  Created by Danny Moesch on 03.03.20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import Intents
import passKit

class IntentHandler: INExtension {
    
    override func handler(for intent: INIntent) -> Any {
        guard intent is SyncRepositoryIntent else {
            fatalError("Unhandled intent type \(intent).")
        }
        return SyncRepositoryIntentHandler()
    }
}
