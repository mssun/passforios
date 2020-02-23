//
//  PasswordTableEntryTest.swift
//  passKitTests
//
//  Created by Yishi Lin on 2020/2/23.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import XCTest

@testable import passKit

class PasswordTableEntryTest: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() {
        let nameWithCategoryList = [
            "github",
            "github.com",
            "www.github.com",
            "personal/github",
            "personal/github.com",
            "personal/www.github.com",
            "github/personal",
            "github.com/personal",
            "www.github.com/personal",
            "github (personal)",
        ]
        let searchTextList1 = [
            "github.com",
            "www.github.com"
        ]
        let searchTextList2 = [
            "xx.com",
            "www.xx.com"
        ]
        
        for nameWithCategory in nameWithCategoryList {
            for searchText in searchTextList1 {
                XCTAssertTrue(PasswordTableEntry.match(nameWithCategory: nameWithCategory, searchText: searchText))
            }
            for searchText in searchTextList2 {
                XCTAssertFalse(PasswordTableEntry.match(nameWithCategory: nameWithCategory, searchText: searchText))
            }
        }
    }

}
