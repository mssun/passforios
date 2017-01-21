//
//  DefaultKeys.swift
//  pass
//
//  Created by Mingshen Sun on 21/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import SwiftyUserDefaults

extension DefaultsKeys {
    static let pgpKeyURL = DefaultsKey<URL?>("pgpKeyURL")

    static let pgpKeyPassphrase = DefaultsKey<String>("pgpKeyPassphrase")
    static let pgpKeyID = DefaultsKey<String>("pgpKeyID")
    static let pgpKeyUserID = DefaultsKey<String>("pgpKeyUserID")
    
    static let gitRepositoryURL = DefaultsKey<URL?>("gitRepositoryURL")
}
