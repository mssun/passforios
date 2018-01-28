//
//  PasscodeLockPresenter.swift
//  PasscodeLock
//
//  Created by Yanko Dimitrov on 8/29/15.
//  Copyright © 2015 Yanko Dimitrov. All rights reserved.
//

import UIKit

open class PasscodeLockPresenter {
    
    fileprivate var mainWindow: UIWindow?
    
    fileprivate lazy var passcodeLockWindow = UIWindow(frame: UIScreen.main.bounds)
        
    open var isPasscodePresented = false
    open let passcodeLockVC: PasscodeLockViewController
    
    public init(mainWindow window: UIWindow?, viewController: PasscodeLockViewController) {
        mainWindow = window
        passcodeLockVC = viewController
    }

    public convenience init(mainWindow window: UIWindow?) {
        let passcodeLockVC = PasscodeLockViewController()
        self.init(mainWindow: window, viewController: passcodeLockVC)
    }
    
    open func present(windowLevel: CGFloat?) {
        guard PasscodeLock.shared.hasPasscode else { return }
        guard !isPasscodePresented else { return }
        
        isPasscodePresented = true

        mainWindow?.endEditing(true)
        moveWindowsToFront(windowLevel: windowLevel)
        passcodeLockWindow.isHidden = false

        let userDismissCompletionCallback = passcodeLockVC.dismissCompletionCallback
        passcodeLockVC.dismissCompletionCallback = { [weak self] in
            userDismissCompletionCallback?()
            self?.dismiss()
        }
        passcodeLockWindow.rootViewController = passcodeLockVC
    }

    open func dismiss() {
        isPasscodePresented = false
        passcodeLockWindow.isHidden = true
        passcodeLockWindow.rootViewController = nil
    }

    fileprivate func moveWindowsToFront(windowLevel: CGFloat?) {
        let windowLevel = windowLevel ?? UIWindowLevelNormal
        let maxWinLevel = max(windowLevel, UIWindowLevelNormal)
        passcodeLockWindow.windowLevel =  maxWinLevel + 1
    }
}
