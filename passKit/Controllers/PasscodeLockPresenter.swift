//
//  PasscodeLockPresenter.swift
//  PasscodeLock
//
//  Created by Yishi Lin on 10/04/2018.
//  Copyright © 2018 Yishi Lin. All rights reserved.
//
//  Inspired by SwiftPasscodeLock created by Yanko Dimitrov.
//

import UIKit

open class PasscodeLockPresenter {

    fileprivate var mainWindow: UIWindow?
    fileprivate var passcodeLockWindow: UIWindow?

    public init(mainWindow window: UIWindow?) {
        self.mainWindow = window
    }

    open func present(windowLevel: CGFloat?) {
        guard PasscodeLock.shared.hasPasscode else { return }

        // dismiss the original window
        dismiss()

        // new window
        mainWindow?.endEditing(true)
        passcodeLockWindow = UIWindow(frame: self.mainWindow!.frame)
        moveWindowsToFront(windowLevel: windowLevel)
        passcodeLockWindow?.isHidden = false

        // new vc
        let passcodeLockVC = PasscodeLockViewController()
        let userDismissCompletionCallback = passcodeLockVC.dismissCompletionCallback
        passcodeLockVC.dismissCompletionCallback = { [weak self] in
            userDismissCompletionCallback?()
            self?.dismiss()
        }
        passcodeLockWindow?.rootViewController = passcodeLockVC
    }

    open func dismiss() {
        passcodeLockWindow?.isHidden = true
        passcodeLockWindow?.rootViewController = nil
    }

    fileprivate func moveWindowsToFront(windowLevel: CGFloat?) {
        let windowLevel = windowLevel ?? UIWindowLevelNormal
        let maxWinLevel = max(windowLevel, UIWindowLevelNormal)
        passcodeLockWindow?.windowLevel =  maxWinLevel + 1
    }
}
