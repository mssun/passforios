//
//  NotificationCenterDispatcher.swift
//  passKit
//
//  Created by Danny Moesch on 29.09.21.
//  Copyright © 2021 Bob Sun. All rights reserved.
//

public class NotificationCenterDispatcher: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationCenterDispatcher()

    public func userNotificationCenter(_: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == Globals.otpNotificationCopyAction {
            if let otp = response.notification.request.content.userInfo["otp"] as? String {
                UIPasteboard.general.string = otp
            }
        }
        completionHandler()
    }

    public static func showOTPNotification(password: Password) {
        guard let otp = password.currentOtp else {
            return
        }
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.getNotificationSettings { state in
            guard state.authorizationStatus == .authorized else {
                return
            }
            let content = UNMutableNotificationContent()
            if Defaults.autoCopyOTP {
                content.title = "OTPForPasswordCopied".localize(password.name)
            } else {
                content.title = "OTPForPassword".localize(password.name)
                content.body = otp
                content.categoryIdentifier = Globals.otpNotificationCategory
                content.userInfo = [
                    "path": password.namePath,
                    "otp": otp,
                ]
            }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: Globals.otpNotification, content: content, trigger: trigger)
            notificationCenter.add(request)
        }
    }
}
