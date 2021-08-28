//
//  ContentProvider.swift
//  pass
//
//  Created by Mingshen Sun on 12/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

protocol ContentProvider {
    func getContent() -> String?
    func setContent(content: String?)
}
