//
//  PasswordTableEntry.swift
//  passKit
//
//  Created by Yishi Lin on 2020/2/23.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import Foundation

public class PasswordTableEntry: NSObject {
    public let passwordEntity: PasswordEntity
    @objc public let title: String
    public let isDir: Bool
    public let synced: Bool
    public let categoryText: String
    
    public init(_ entity: PasswordEntity) {
        self.passwordEntity = entity
        self.title = entity.name!
        self.isDir = entity.isDir
        self.synced = entity.synced
        self.categoryText = entity.getCategoryText()
    }
    
    public func match(_ searchText: String) -> Bool {
        return PasswordTableEntry.match(nameWithCategory: passwordEntity.nameWithCategory, searchText: searchText)
    }
    
    public static func match(nameWithCategory: String, searchText: String) -> Bool {
        let titleSplit = nameWithCategory.split{ !($0.isLetter || $0.isNumber || $0 == ".") }
        for str in titleSplit {
            if (str.localizedCaseInsensitiveContains(searchText)) {
                return true
            }
            if (searchText.localizedCaseInsensitiveContains(str)) {
                return true
            }
        }
        
        return false
    }
}

