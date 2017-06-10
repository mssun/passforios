//
//  ActionViewController.swift
//  passforiosextension
//
//  Created by Yishi Lin on 9/6/17.
//  Copyright © 2017 Yishi Lin. All rights reserved.
//

import UIKit
import MobileCoreServices

class ActionViewController: UIViewController {

    @IBOutlet weak var textView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let item = extensionContext?.inputItems.first as! NSExtensionItem
        let provider = item.attachments?.first as! NSItemProvider
        let propertyList = String(kUTTypePropertyList)
        if provider.hasItemConformingToTypeIdentifier(propertyList) {
            provider.loadItem(forTypeIdentifier: propertyList, options: nil, completionHandler: { (item, error) -> Void in
                let dictionary = item as! NSDictionary
                let results = dictionary[NSExtensionJavaScriptPreprocessingResultsKey] as! NSDictionary
                let url = results["url"] as? String
                DispatchQueue.main.async { [weak self] in
                    self?.textView.text = url
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
