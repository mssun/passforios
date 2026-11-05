//
//  AppDelegate.swift
//  pass
//
//  Created by Mingshen Sun on 18/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import CoreData
import passKit
import SVProgressHUD
import SwiftyUserDefaults
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        SVProgressHUD.setMinimumSize(CGSize(width: 150, height: 100))
        UNUserNotificationCenter.current().delegate = NotificationCenterDispatcher.shared
        return true
    }

    func application(_: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if window?.rootViewController is PasscodeLockViewController {
            window?.frame = UIScreen.main.bounds
        }
        return .all
    }

    func applicationWillTerminate(_: UIApplication) {
        PersistenceController.shared.save()
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    private enum ViewTag: Int {
        case blur = 100, appicon
    }

    var window: UIWindow?

    private lazy var passcodeLockPresenter = PasscodeLockPresenter(mainWindow: window)

    func sceneWillEnterForeground(_: UIScene) {
        passcodeLockPresenter.present(windowLevel: window?.windowLevel.rawValue)
    }

    func sceneWillResignActive(_: UIScene) {
        guard let window else {
            return
        }

        let blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
        blurEffectView.frame = window.bounds
        blurEffectView.tag = ViewTag.blur.rawValue
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(blurEffectView)

        let iconsDictionary = Bundle.main.infoDictionary?["CFBundleIcons"] as? NSDictionary
        let primaryIconsDictionary = iconsDictionary?["CFBundlePrimaryIcon"] as? NSDictionary
        if let iconFiles = primaryIconsDictionary?["CFBundleIconFiles"] as? [String],
           let iconName = iconFiles.last,
           let appIcon = UIImage(named: iconName) {
            let appIconView = UIImageView(image: appIcon)
            appIconView.layer.cornerRadius = appIcon.size.height / 5
            appIconView.layer.masksToBounds = true
            appIconView.center = CGPoint(x: window.bounds.midX, y: window.bounds.midY)
            appIconView.tag = ViewTag.appicon.rawValue
            window.addSubview(appIconView)
        }

        PersistenceController.shared.save()
    }

    func sceneDidEnterBackground(_: UIScene) {
        PersistenceController.shared.save()
    }

    func sceneDidBecomeActive(_: UIScene) {
        window?.viewWithTag(ViewTag.appicon.rawValue)?.removeFromSuperview()
        window?.viewWithTag(ViewTag.blur.rawValue)?.removeFromSuperview()
    }

    func scene(_: UIScene, willConnectTo _: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let shortcutItem = connectionOptions.shortcutItem {
            _ = handle(shortcutItem: shortcutItem)
        }
    }

    func windowScene(
        _: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(handle(shortcutItem: shortcutItem))
    }

    private func handle(shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard shortcutItem.type == Globals.bundleIdentifier + ".search" else {
            return false
        }

        if let tabBarController = window?.rootViewController as? UITabBarController {
            tabBarController.selectedIndex = 0
            if let navigationController = tabBarController.selectedViewController as? UINavigationController {
                navigationController.popToRootViewController(animated: false)
            }
        }
        perform(#selector(postSearchNotification), with: nil, afterDelay: 0.4)
        return true
    }

    @objc
    private func postSearchNotification() {
        NotificationCenter.default.post(name: .passwordSearch, object: nil)
    }
}
