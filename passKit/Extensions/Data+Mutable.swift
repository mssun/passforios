//
//  Data+Mutable.swift
//  passKit
//
//  Created by Danny Moesch on 08.09.19.
//  Copyright © 2019 Bob Sun. All rights reserved.
//

extension Data {
    /// This computed value is only needed because of [this](https://github.com/golang/go/issues/33745) issue in the
    /// golang/go repository. It is a workaround until the problem is solved upstream.
    ///
    /// The data object is converted into an array of bytes and than returned wrapped in an `NSMutableData` object. In
    /// thas way Gomobile takes it as it is without copying. The Swift side remains responsible for garbage collection.
    var mutable: NSMutableData {
        var array = [UInt8](self)
        return NSMutableData(bytes: &array, length: count)
    }
}
