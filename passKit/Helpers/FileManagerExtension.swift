//
//  FileManagerExtension.swift
//  passKit
//
//  Created by Yishi Lin on 2018/9/23.
//  Copyright © 2018 Bob Sun. All rights reserved.
//

import Foundation

// https://gist.github.com/NikolaiRuhe/eeb135d20c84a7097516
public extension FileManager {
    /// This method calculates the accumulated size of a directory on the volume in bytes.
    ///
    /// As there's no simple way to get this information from the file system it has to crawl the entire hierarchy,
    /// accumulating the overall sum on the way. The resulting value is roughly equivalent with the amount of bytes
    /// that would become available on the volume if the directory would be deleted.
    ///
    /// - note: There are a couple of oddities that are not taken into account (like symbolic links, meta data of
    /// directories, hard links, ...).
    func allocatedSizeOfDirectoryAtURL(directoryURL: URL) throws -> UInt64 {
        // We'll sum up content size here:
        var accumulatedSize = UInt64(0)

        // prefetching some properties during traversal will speed up things a bit.
        let prefetchedProperties = [
            URLResourceKey.isRegularFileKey,
            URLResourceKey.fileAllocatedSizeKey,
            URLResourceKey.totalFileAllocatedSizeKey,
        ]

        // The error handler simply signals errors to outside code.
        var errorDidOccur: Error?
        let errorHandler: (URL, Error) -> Bool = { _, error in
            errorDidOccur = error
            return false
        }

        // We have to enumerate all directory contents, including subdirectories.
        let enumerator = self.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: prefetchedProperties,
            options: Self.DirectoryEnumerationOptions(),
            errorHandler: errorHandler
        )
        precondition(enumerator != nil)

        // Start the traversal:
        for item in enumerator! {
            let contentItemURL = item as! NSURL

            // Bail out on errors from the errorHandler.
            if let error = errorDidOccur { throw error }

            let resourceValueForKey: (URLResourceKey) throws -> NSNumber? = { key in
                var value: AnyObject?
                try contentItemURL.getResourceValue(&value, forKey: key)
                return value as? NSNumber
            }

            // Get the type of this item, making sure we only sum up sizes of regular files.
            guard let isRegularFile = try resourceValueForKey(URLResourceKey.isRegularFileKey) else {
                preconditionFailure()
            }

            guard isRegularFile.boolValue else {
                continue
            }

            // To get the file's size we first try the most comprehensive value in terms of what the file may use on disk.
            // This includes metadata, compression (on file system level) and block size.
            var fileSize = try resourceValueForKey(URLResourceKey.totalFileAllocatedSizeKey)

            // In case the value is unavailable we use the fallback value (excluding meta data and compression)
            // This value should always be available.
            fileSize = try fileSize ?? resourceValueForKey(URLResourceKey.fileAllocatedSizeKey)

            guard let size = fileSize else {
                preconditionFailure("NSURLFileAllocatedSizeKeyShouldAlwaysReturnValue.".localize())
            }

            // We're good, add up the value.
            accumulatedSize += size.uint64Value
        }

        // Bail out on errors from the errorHandler.
        if let error = errorDidOccur { throw error }

        // We finally got it.
        return accumulatedSize
    }
}
