//
//  Utils.swift
//  pass
//
//  Created by Mingshen Sun on 8/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import SwiftyUserDefaults
import KeychainAccess

public class Utils {
    public static func removeFileIfExists(atPath path: String) {
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: path) {
                try fm.removeItem(atPath: path)
            }
        } catch {
            print(error)
        }
    }
    public static func removeFileIfExists(at url: URL) {
        removeFileIfExists(atPath: url.path)
    }

    public static func getLastSyncedTimeString() -> String {
        guard let lastSyncedTime = SharedDefaults[.lastSyncedTime] else {
            return "Oops! Sync again?"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: lastSyncedTime)
    }
    
    public static func generatePassword(length: Int) -> String{
        switch SharedDefaults[.passwordGeneratorFlavor] {
        case "Random":
            return randomString(length: length)
        case "Apple":
            return Keychain.generatePassword()
        default:
            return randomString(length: length)
        }
    }
    
    public static func randomString(length: Int) -> String {
        
        let letters : NSString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*_+-="
        let len = UInt32(letters.length)
        
        var randomString = ""
        
        for _ in 0 ..< length {
            let rand = arc4random_uniform(len)
            var nextChar = letters.character(at: Int(rand))
            randomString += NSString(characters: &nextChar, length: 1) as String
        }
        
        return randomString
    }
    
    public static func getPasswordFromKeychain(name: String) -> String? {
        let keychain = Keychain(service: Globals.bundleIdentifier, accessGroup: Globals.groupIdentifier)
        do {
            return try keychain.getString(name)
        } catch {
            print(error)
        }
        return nil
    }
    
    public static func addPasswordToKeychain(name: String, password: String?) {
        let keychain = Keychain(service: Globals.bundleIdentifier, accessGroup: Globals.groupIdentifier)
        keychain[name] = password
    }
    
    public static func removeKeychain(name: String) {
        let keychain = Keychain(service: Globals.bundleIdentifier, accessGroup: Globals.groupIdentifier)
        do {
            try keychain.remove(name)
        } catch {
            print(error)
        }
    }
    
    public static func removeAllKeychain() {
        let keychain = Keychain(service: Globals.bundleIdentifier, accessGroup: Globals.groupIdentifier)
        do {
            try keychain.removeAll()
        } catch {
            print(error)
        }
    }
    public static func copyToPasteboard(textToCopy: String?) {
        guard textToCopy != nil else {
            return
        }
        UIPasteboard.general.string = textToCopy
    }
    public static func attributedPassword(plainPassword: String) -> NSAttributedString{
        let attributedPassword = NSMutableAttributedString.init(string: plainPassword)
        // draw all digits in the password into red
        // draw all punctuation characters in the password into blue
        for (index, element) in plainPassword.unicodeScalars.enumerated() {
            var charColor = UIColor.darkText
            if NSCharacterSet.decimalDigits.contains(element) {
                charColor = Globals.digitColor
            } else if !NSCharacterSet.letters.contains(element) {
                charColor = Globals.letterColor
            }
            attributedPassword.addAttribute(NSAttributedStringKey.foregroundColor, value: charColor, range: NSRange(location: index, length: 1))
        }
        return attributedPassword
    }
    public static func initDefaultKeys() {
        if SharedDefaults[.passwordGeneratorFlavor] == "" {
            SharedDefaults[.passwordGeneratorFlavor] = "Random"
        }
    }
}

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
    func allocatedSizeOfDirectoryAtURL(directoryURL : URL) throws -> UInt64 {
        
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
        let enumerator = self.enumerator(at: directoryURL,
                                              includingPropertiesForKeys: prefetchedProperties,
                                              options: FileManager.DirectoryEnumerationOptions(),
                                              errorHandler: errorHandler)
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
                preconditionFailure("huh? NSURLFileAllocatedSizeKey should always return a value")
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

public extension String {
    func stringByAddingPercentEncodingForRFC3986() -> String? {
        let unreserved = "-._~/?"
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: unreserved)
        return addingPercentEncoding(withAllowedCharacters: allowed)
    }
}
