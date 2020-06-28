//
//  Array+Slices.swift
//  passKit
//
//  Created by Danny Moesch on 28.02.20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

extension Array {
    func slices(count: UInt) -> [ArraySlice<Element>] {
        guard count != 0 else {
            return []
        }
        let sizeEach = Int(self.count / Int(count))
        var currentIndex = startIndex
        var slices = [ArraySlice<Element>]()
        for _ in 0 ..< count {
            let toIndex = index(currentIndex, offsetBy: sizeEach, limitedBy: endIndex) ?? endIndex
            slices.append(self[currentIndex ..< toIndex])
            currentIndex = toIndex
        }
        if currentIndex != endIndex {
            slices[slices.endIndex - 1].append(contentsOf: self[currentIndex ..< endIndex])
        }
        return slices
    }
}
