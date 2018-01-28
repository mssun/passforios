//
//  AppDelegate.swift
//  pass
//
//  Created by Mingshen Sun on 18/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit
import CoreData
import SVProgressHUD
import passKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    enum ViewTag: Int {
        case blur = 100, appicon
    }

    lazy var passcodeLockPresenter: PasscodeLockPresenter = {
        let presenter = PasscodeLockPresenter(mainWindow: self.window)
        return presenter
    }()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        SVProgressHUD.setMinimumSize(CGSize(width: 150, height: 100))
        passcodeLockPresenter.present(windowLevel: UIApplication.shared.windows.last?.windowLevel)
        if let shortcutItem = launchOptions?[UIApplicationLaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem {
            if shortcutItem.type == Globals.bundleIdentifier + ".search" {
                self.perform(#selector(postSearchNotification), with: nil, afterDelay: 0.4)
            }
        }
        Utils.initDefaultKeys()
        return true
    }
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if let _ = window?.rootViewController as? PasscodeLockViewController {
            window?.frame = UIScreen.main.bounds
        }
        return .all
    }
    
    @objc func postSearchNotification() {
        NotificationCenter.default.post(name: .passwordSearch, object: nil)
    }
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        if shortcutItem.type == Globals.bundleIdentifier + ".search" {
            let tabBarController = self.window!.rootViewController as! UITabBarController
            tabBarController.selectedIndex = 0
            let navigationController = tabBarController.selectedViewController as! UINavigationController
            navigationController.popToRootViewController(animated: false)
            self.perform(#selector(postSearchNotification), with: nil, afterDelay: 0.4)
        }
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        
        // Display a blur effect view
        let blurEffect = UIBlurEffect(style: UIBlurEffectStyle.light)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = (self.window?.frame)!
        blurEffectView.tag = ViewTag.blur.rawValue
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.window?.addSubview(blurEffectView)
        
        // Display the Pass icon in the middle of the screen
        let iconsDictionary = Bundle.main.infoDictionary?["CFBundleIcons"] as? NSDictionary
        let primaryIconsDictionary = iconsDictionary?["CFBundlePrimaryIcon"] as? NSDictionary
        let iconFiles = primaryIconsDictionary!["CFBundleIconFiles"] as! NSArray
        let appIcon = UIImage(named: iconFiles.lastObject as! String)
        let appIconView = UIImageView(image: appIcon)
        appIconView.layer.cornerRadius = (appIcon?.size.height)! / 5
        appIconView.layer.masksToBounds = true
        appIconView.center = (self.window?.center)!
        appIconView.tag = ViewTag.appicon.rawValue
        self.window?.addSubview(appIconView)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        passcodeLockPresenter.present(windowLevel: UIApplication.shared.windows.last?.windowLevel)
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        
        self.window?.viewWithTag(ViewTag.appicon.rawValue)?.removeFromSuperview()
        self.window?.viewWithTag(ViewTag.blur.rawValue)?.removeFromSuperview()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        self.saveContext()
    }

    // MARK: - Core Data stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let modelURL = Bundle(identifier: Globals.passKitBundleIdentifier)!.url(forResource: "pass", withExtension: "momd")!
        let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)
        let container = NSPersistentContainer(name: "pass", managedObjectModel: managedObjectModel!)
        if FileManager.default.fileExists(atPath: Globals.documentPath) {
            try! FileManager.default.createDirectory(atPath: Globals.documentPath, withIntermediateDirectories: true, attributes: nil)
        }
        container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: URL(fileURLWithPath: Globals.dbPath))]
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    // MARK: - Core Data Saving support
    
    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

}

