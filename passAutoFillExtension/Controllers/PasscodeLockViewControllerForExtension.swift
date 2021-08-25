//
//  PasscodeLockViewControllerForExtension.swift
//  passAutoFillExtension
//
//  Created by Danny Moesch on 24.08.21.
//  Copyright © 2021 Bob Sun. All rights reserved.
//

import passKit

class PasscodeLockViewControllerForExtension: PasscodeLockViewController {
    var originalExtensionContext: NSExtensionContext!

    convenience init(extensionContext: NSExtensionContext) {
        self.init()
        self.originalExtensionContext = extensionContext
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        cancelButton?.removeTarget(nil, action: nil, for: .allEvents)
        // cancel means cancel the extension
        cancelButton?.addTarget(self, action: #selector(cancelExtension), for: .touchUpInside)
    }

    @objc
    func cancelExtension() {
        originalExtensionContext.cancelRequest(withError: NSError(domain: "PassExtension", code: 0))
    }
}
