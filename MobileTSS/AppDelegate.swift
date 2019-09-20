//
//  AppDelegate.swift
//  MobileTSS
//
//  Created by User on 7/2/18.
//  Copyright © 2018 User. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    private(set) static var expirationDate: Date?
    private static let LocalNotificationTitleKey = "LocalNotificationTitleKey"
    private static let LocalNotificationMessageBodyKey = "LocalNotificationMessageBodyKey"
    private static let LocalNotificationTypeKey = "LocalNotificationTypeKey"
    private static let LocalNotificationCategoryFetchIdentifier = "Fetch"
    private static let LocalNotificationCategoryRetryIdentifier = "Retry"
    private static let LocalNotificationUserInfoFromKey = "From"
//    private static let LocalNotificationUserInfoToKey = "To"
    private enum LocalNotificationType : Int {
        case expiration = 0
        case backgroundFetch = 1
    }
//    private static let LocalNotificationFireDate = "LocalNotificationMessageBodyKey"

    class func scheduleExpirationNotification(expirationDate: Date) {
        // do not schedule if expired in 24 hours.
        guard expirationDate.timeIntervalSinceNow > 24*60*60 else {return}
        let notification = UILocalNotification()
        if #available(iOS 8.2, *) {
            notification.alertTitle = "Expiration Warning"
        }
        let alertBody = "MobileTSS will expire in 24 hours. Keep in mind you need to resign it after it expires."
        notification.alertBody = alertBody
        notification.fireDate = expirationDate.addingTimeInterval(-24*60*60)
        notification.soundName = UILocalNotificationDefaultSoundName
        notification.userInfo = [
            AppDelegate.LocalNotificationTitleKey : "Expiration",
            AppDelegate.LocalNotificationMessageBodyKey : alertBody,
            AppDelegate.LocalNotificationTypeKey : LocalNotificationType.expiration.rawValue
        ]
        UIApplication.shared.scheduleLocalNotification(notification)
    }
    class func registerNotificationPermission() {
        let fetchNextAction = UIMutableUserNotificationAction()
        fetchNextAction.activationMode = .background
        fetchNextAction.title = "Next"
        fetchNextAction.identifier = LocalNotificationCategoryFetchIdentifier
        fetchNextAction.isAuthenticationRequired = false
        let fetchNextCategory = UIMutableUserNotificationCategory()
        fetchNextCategory.identifier = LocalNotificationCategoryFetchIdentifier
        fetchNextCategory.setActions([fetchNextAction], for: .default)

        let errorCategory = UIMutableUserNotificationCategory()
        errorCategory.identifier = LocalNotificationCategoryRetryIdentifier
        let retryAction = UIMutableUserNotificationAction()
        retryAction.activationMode = .background
        retryAction.title = LocalNotificationCategoryRetryIdentifier
        retryAction.identifier = LocalNotificationCategoryRetryIdentifier
        retryAction.isAuthenticationRequired = false
        errorCategory.setActions([retryAction], for: .default)

        UIApplication.shared.registerUserNotificationSettings(.init(types: [.alert, .badge, .sound], categories: Set([fetchNextCategory, errorCategory])))
    }
    class func cancelExpirationNotification() {
        guard let scheduledExpirationNotification = UIApplication.shared.scheduledLocalNotifications?.first(where: { (localNotification) -> Bool in
            if let num = localNotification.userInfo?[AppDelegate.LocalNotificationTypeKey] as? Int, LocalNotificationType(rawValue: num) == .expiration {
                return true
            }
            return false
        }) else {return}
        UIApplication.shared.cancelLocalNotification(scheduledExpirationNotification)
    }
    func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?, for notification: UILocalNotification, completionHandler: @escaping () -> Void) {
        if let from = notification.userInfo?[AppDelegate.LocalNotificationUserInfoFromKey] as? Int {
            application.applicationIconBadgeNumber = 1
            application.applicationIconBadgeNumber = 0
            fetchingSigningAtBackground(range: (from, from + 6)) { _ in
                completionHandler()
            }
        }
    }
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        if (application.currentUserNotificationSettings?.types.contains(.badge)) == true {
            application.applicationIconBadgeNumber = 0
        }
        TSSRequest.setBuildManifestStorageLocation(GlobalConstants.buildManifestDirectoryPath)
        TSSRequest.savingDestination = GlobalConstants.documentsDirectoryPath
        #if DEBUG
        print(GlobalConstants.documentsDirectoryPath)
        #endif
        // not sure if this works
        if let mobileprovision = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") {
            let dic = NSDictionary.init(contentsOfFile: mobileprovision, head: "<?xml", includedTail: "</plist>")
            let date = dic?.object(forKey: "ExpirationDate") as! Date
            AppDelegate.expirationDate = date
            if PreferencesTableViewController.isExpirationNotificationOn && application.currentUserNotificationSettings?.types.contains(.alert) ?? false {
                let scheduledExpirationNotification = application.scheduledLocalNotifications?.first(where: { (localNotification) -> Bool in
                    if let num = localNotification.userInfo?[AppDelegate.LocalNotificationTypeKey] as? Int, LocalNotificationType(rawValue: num) == .expiration {
                        return true
                    }
                    return false
                })
                if scheduledExpirationNotification?.fireDate != date {
                    if let scheduledExpirationNotification = scheduledExpirationNotification {
                        application.cancelLocalNotification(scheduledExpirationNotification)
                    }
                    AppDelegate.scheduleExpirationNotification(expirationDate: date)
                }
            }
        }
        else {
            AppDelegate.cancelExpirationNotification()
        }
        return true
    }
    func application(_ application: UIApplication, didReceive notification: UILocalNotification) {
        if (application.currentUserNotificationSettings?.types.contains(.badge)) == true {
            application.applicationIconBadgeNumber = 1
            application.applicationIconBadgeNumber = 0
        }
        guard let rawType = notification.userInfo?[AppDelegate.LocalNotificationTypeKey] as? Int, let type = AppDelegate.LocalNotificationType(rawValue: rawType) else {return}
        switch type {
        case .expiration:
            let alertView = UIAlertController(title: notification.userInfo?[AppDelegate.LocalNotificationTitleKey] as? String, message: notification.userInfo?[AppDelegate.LocalNotificationMessageBodyKey] as? String, preferredStyle: .alert)
            alertView.addAction(UIAlertAction(title: "OK", style: .cancel))
            self.window?.rootViewController?.present(alertView, animated: true)
            break
        case .backgroundFetch:
            if application.applicationState == .inactive {
                (self.window?.rootViewController as! UITabBarController).selectedIndex = 1
            }
        }
    }
    func application(_ application: UIApplication, didRegister notificationSettings: UIUserNotificationSettings) {
        if PreferencesTableViewController.isExpirationNotificationOn, let expirationDate = AppDelegate.expirationDate {
            AppDelegate.scheduleExpirationNotification(expirationDate: expirationDate)
        }
    }
    private func fetchingSigningAtBackground(range: CustomFirmwareTableViewController.TSSRequestRange, completionHandler: ((UIBackgroundFetchResult) -> Void)? = nil) {
        let duration = Date().timeIntervalSince1970

        let superVC = (self.window?.rootViewController as! UITabBarController)
        let cftvc = (superVC.viewControllers![1] as! UINavigationController).viewControllers.first as! CustomFirmwareTableViewController

        cftvc.checkSigningStatusInBackground(range: (range.from, min(cftvc.numberOfRequest, range.to))) { (signingStatusArray) in
            if signingStatusArray.isEmpty {
                completionHandler?(.noData)
            }
            else {
                var notificationText = String()
                var error = false
                var signed = false
                for index in 0..<signingStatusArray.count {
                    let (model, version, status) = signingStatusArray[index]
                    notificationText += "\(model) - \(version)"
                    switch status {
                    case .Signed:
                        notificationText += ": ✅; "
                        signed = true
                    case .Not_Signed:
                        notificationText += ": ❌; "
                    case .Error:
                        error = true
                        notificationText += ": ⚠️; "
                    default: break
                    }
                    if index % 2 == 1 {
                        notificationText += "\n"
                    }
                }
                if notificationText.last != "\n" {
                    notificationText += "\n"
                }
                notificationText += String(format: "Duration: %.02f", Date().timeIntervalSince1970 - duration)
                let resultNotification = UILocalNotification()
                resultNotification.alertBody = notificationText
                var userInfo: [String : Any] = [AppDelegate.LocalNotificationTypeKey : AppDelegate.LocalNotificationType.backgroundFetch.rawValue]
                if error {
                    resultNotification.category = AppDelegate.LocalNotificationCategoryRetryIdentifier
                    userInfo[AppDelegate.LocalNotificationUserInfoFromKey] = range.from
                }
                else if range.to < cftvc.numberOfRequest {
                    resultNotification.category = AppDelegate.LocalNotificationCategoryFetchIdentifier
                    userInfo[AppDelegate.LocalNotificationUserInfoFromKey] = range.to
                }
                resultNotification.userInfo = userInfo
                if signed {
                    resultNotification.soundName = UILocalNotificationDefaultSoundName
                }
                UIApplication.shared.scheduleLocalNotification(resultNotification)
                cftvc.tableView.reloadData()
                completionHandler?(error ? .failed : .newData)
            }
        }
    }

    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard PreferencesTableViewController.isBackgroundFetchingOn else {
            completionHandler(.noData)
            return
        }
        // fetch 6 firmwares at once.
        fetchingSigningAtBackground(range: (0, 6), completionHandler: completionHandler)
    }
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.

    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
}
