//
//  PasswordDetailViewController.swift
//  pass
//
//  Created by Mingshen Sun on 18/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import SwiftyUserDefaults

class PasswordDetailViewController: UIViewController {

    @IBOutlet weak var passwordTextView: UITextView!
    var passwordEntity: PasswordEntity?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let encryptedDataURL = URL(fileURLWithPath: "\(Globals.shared.documentPath)/\(passwordEntity!.rawPath!)")
        let fm = FileManager.default
        if fm.fileExists(atPath: encryptedDataURL.path){
            print("file exist")
        } else {
            print("file doesnt exist")
        }
        
        do {
            let encryptedData = try Data(contentsOf: encryptedDataURL)
            let decryptedData = try PasswordStore.shared.pgp.decryptData(encryptedData, passphrase: Defaults[.pgpKeyPassphrase])
            let plain = String(data: decryptedData, encoding: .ascii) ?? ""
            print(plain)
            passwordTextView.text = plain
        }  catch let error as NSError {
            print(error.debugDescription)
        }
        
    }
}
