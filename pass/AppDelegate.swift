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
    enum ViewTag: Int {
        case blur = 100, appicon
    }

    var window: UIWindow?

    lazy var passcodeLockPresenter = PasscodeLockPresenter(mainWindow: self.window)

    func application(_: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        SVProgressHUD.setMinimumSize(CGSize(width: 150, height: 100))
        passcodeLockPresenter.present(windowLevel: UIApplication.shared.windows.last?.windowLevel.rawValue)
        if let shortcutItem = launchOptions?[UIApplication.LaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem {
            if shortcutItem.type == Globals.bundleIdentifier + ".search" {
                perform(#selector(postSearchNotification), with: nil, afterDelay: 0.4)
            }
        }
        UNUserNotificationCenter.current().delegate = NotificationCenterDispatcher.shared
        return true
    }

    func application(_: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if window?.rootViewController is PasscodeLockViewController {
            window?.frame = UIScreen.main.bounds
        }
        return .all
    }

    @objc
    func postSearchNotification() {
        NotificationCenter.default.post(name: .passwordSearch, object: nil)
    }

    func application(_: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler _: @escaping (Bool) -> Void) {
        if shortcutItem.type == Globals.bundleIdentifier + ".search" {
            let tabBarController = window!.rootViewController as! UITabBarController
            tabBarController.selectedIndex = 0
            let navigationController = tabBarController.selectedViewController as! UINavigationController
            navigationController.popToRootViewController(animated: false)
            perform(#selector(postSearchNotification), with: nil, afterDelay: 0.4)
        }
    }

    func applicationWillResignActive(_: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.

        // Display a blur effect view
        let blurEffect = UIBlurEffect(style: UIBlurEffect.Style.light)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = (window?.frame)!
        blurEffectView.tag = ViewTag.blur.rawValue
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window?.addSubview(blurEffectView)

        // Display the Pass icon in the middle of the screen
        let iconsDictionary = Bundle.main.infoDictionary?["CFBundleIcons"] as? NSDictionary
        let primaryIconsDictionary = iconsDictionary?["CFBundlePrimaryIcon"] as? NSDictionary
        let iconFiles = primaryIconsDictionary!["CFBundleIconFiles"] as! NSArray
        let appIcon = UIImage(named: iconFiles.lastObject as! String)
        let appIconView = UIImageView(image: appIcon)
        appIconView.layer.cornerRadius = (appIcon?.size.height)! / 5
        appIconView.layer.masksToBounds = true
        appIconView.center = (window?.center)!
        appIconView.tag = ViewTag.appicon.rawValue
        window?.addSubview(appIconView)

        PersistenceController.shared.save()
    }

    func applicationDidEnterBackground(_: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        passcodeLockPresenter.present(windowLevel: UIApplication.shared.windows.last?.windowLevel.rawValue)
    }

    func applicationDidBecomeActive(_: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.

        window?.viewWithTag(ViewTag.appicon.rawValue)?.removeFromSuperview()
        window?.viewWithTag(ViewTag.blur.rawValue)?.removeFromSuperview()
    }

    func applicationWillTerminate(_: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        PersistenceController.shared.save()
    }
}
