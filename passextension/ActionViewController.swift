//
//  ActionViewController.swift
//  passforiosextension
//
//  Created by Yishi Lin on 9/6/17.
//  Copyright © 2017 Yishi Lin. All rights reserved.
//

import UIKit
import MobileCoreServices
import passKit

class ActionViewController: UIViewController {

    @IBOutlet weak var textView: UITextView!
    let passwordStore = PasswordStore.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let item = extensionContext?.inputItems.first as! NSExtensionItem
        let provider = item.attachments?.first as! NSItemProvider
        let propertyList = String(kUTTypePropertyList)
        if provider.hasItemConformingToTypeIdentifier(propertyList) {
            provider.loadItem(forTypeIdentifier: propertyList, options: nil, completionHandler: { (item, error) -> Void in
                let dictionary = item as! NSDictionary
                let results = dictionary[NSExtensionJavaScriptPreprocessingResultsKey] as! NSDictionary
                let url = URL(string: (results["url"] as? String)!)?.host
                
                let numberFormatter = NumberFormatter()
                numberFormatter.numberStyle = NumberFormatter.Style.decimal
            
                let numberOfPasswordsString = "Number of password:" + numberFormatter.string(from: NSNumber(value: self.passwordStore.numberOfPasswords))!
                let sizeOfRepositoryString = "Size of repo:" + ByteCountFormatter.string(fromByteCount: Int64(self.passwordStore.sizeOfRepositoryByteCount), countStyle: ByteCountFormatter.CountStyle.file)
                var numberOfCommits: UInt = 0
                
                do {
                    if let _ = try self.passwordStore.storeRepository?.currentBranch().oid {
                        numberOfCommits = self.passwordStore.storeRepository?.numberOfCommits(inCurrentBranch: NSErrorPointer(nilLiteral: ())) ?? 0
                    }
                } catch {
                    print(error)
                }
                let numberOfCommitsString = "Number of commits:" + numberFormatter.string(from: NSNumber(value: numberOfCommits))!
                
                let gitURL = SharedDefaults[.gitURL]!
            
                DispatchQueue.main.async { [weak self] in
                    self?.textView.text = url!
                    print(numberOfPasswordsString)
                    print(numberOfCommitsString)
                    print(sizeOfRepositoryString)
                    print(gitURL)
                }
            })
        } else {
            print("error")
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func done() {
        // Return any edited content to the host app.
        // This template doesn't do anything, so we just echo the passed in items.
        self.extensionContext!.completeRequest(returningItems: self.extensionContext!.inputItems, completionHandler: nil)
    }

}
