//
//  PasscodeLockPresenter.swift
//  passKit
//
//  Created by Yishi Lin on 10/04/2018.
//  Copyright © 2018 Yishi Lin. All rights reserved.
//
//  Inspired by SwiftPasscodeLock created by Yanko Dimitrov.
//

import UIKit

open class PasscodeLockPresenter {
    private var mainWindow: UIWindow?
    private var passcodeLockWindow: UIWindow?

    public init(mainWindow window: UIWindow?) {
        self.mainWindow = window
    }

    open func present(windowLevel: CGFloat?) {
        guard PasscodeLock.shared.hasPasscode else {
            return
        }

        // dismiss the original window
        dismiss()

        // new window
        mainWindow?.endEditing(true)
        passcodeLockWindow = UIWindow(frame: mainWindow!.frame)
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

    private func moveWindowsToFront(windowLevel: CGFloat?) {
        let windowLevel = windowLevel ?? UIWindow.Level.normal.rawValue
        let maxWinLevel = max(windowLevel, UIWindow.Level.normal.rawValue)
        passcodeLockWindow?.windowLevel = UIWindow.Level(rawValue: maxWinLevel + 1)
    }
}
