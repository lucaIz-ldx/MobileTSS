//
//  AppDelegate.swift
//  MobileTSS
//
//  Created by User on 7/2/18.
//  Copyright © 2018 User. All rights reserved.
//

import UIKit
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    private struct NotificationKey {
        struct UserInfoKeys {
            static let from = "UserInfoRangeFrom"
            static let type = "LocalNotificationTypeKey"
        }
        struct CategoryKeys {
            static let fetch = "MobileTSS.category.fetch"
            static let retry = "MobileTSS.category.retry"
        }
        struct ActionsKeys {
            static let fetch = "MobileTSS.action.fetch"
            static let retry = "MobileTSS.action.retry"
        }
//        static let title = "LocalNotificationTitleKey"
//        static let messageBody = "LocalNotificationMessageBodyKey"
//    private static let LocalNotificationUserInfoToKey = "To"
    }

    private enum LocalNotificationType : Int {
        case backgroundFetch = 1
    }
    
    // fetch 6 firmwares at once when background fetching.
    let numOfRequestsFetchedOne = 6

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        UNUserNotificationCenter.current().delegate = self

        let fetchNextAction = UNNotificationAction(identifier: NotificationKey.ActionsKeys.fetch, title: "Next")
        let fetchNextCategory = UNNotificationCategory(identifier: NotificationKey.CategoryKeys.fetch, actions: [fetchNextAction], intentIdentifiers: [])
        
        let retryAction = UNNotificationAction(identifier: NotificationKey.ActionsKeys.retry, title: "Retry")
        let errorCategory = UNNotificationCategory(identifier: NotificationKey.CategoryKeys.retry, actions: [retryAction], intentIdentifiers: [])
        
        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories([fetchNextCategory, errorCategory])
        
        TSSRequest.buildManifestCacheDirectory = GlobalConstants.buildManifestDirectoryPath
        #if DEBUG
        print(GlobalConstants.documentsDirectoryPath)
        #endif
        
//        updateDatabase()
        return true
    }
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(updateProfileViaShortcutItem(shortcutItem))
    }

    private func fetchingSigningAtBackground(range: CustomFirmwareTableViewController.TSSRequestRange, completionHandler: ((UIBackgroundFetchResult) -> Void)? = nil) {
        let duration = Date().timeIntervalSince1970

        let superVC = (window?.rootViewController as! UITabBarController)
        let cftvc = (superVC.viewControllers![1] as! UINavigationController).viewControllers.first as! CustomFirmwareTableViewController

        cftvc.checkSigningStatusInBackground(range: (range.from, min(cftvc.numberOfRequest, range.to))) { (signingStatusArray) in
            if signingStatusArray.isEmpty {
                completionHandler?(.noData)
            }
            else {
                UNUserNotificationCenter.current().getNotificationSettings { (settings) in
                    DispatchQueue.main.async {
                        cftvc.tableView.reloadData()
                    }
                    guard settings.authorizationStatus == .authorized && settings.alertSetting == .enabled else {
                        completionHandler?(signingStatusArray.first {$0.status == .error} != nil ? .failed : .newData)
                        return
                    }
                    var notificationText = String()
                    var error = false
                    var signed = false
                    for index in 0..<signingStatusArray.count {
                        let item = signingStatusArray[index]
                        let (model, version, status) = (item.model, item.version, item.status)
                        notificationText += "\(model) - \(version)"
                        switch status {
                        case .signed:
                            notificationText += ": ✅; "
                            signed = true
                        case .notSigned:
                            notificationText += ": ❌; "
                        case .error:
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
                    
                    let notificationRequest: UNNotificationRequest = {
                        let localNotificationRequestIdentifier = "Notification_\(Date().timeIntervalSince1970)"
                        var userInfo: [String : Any] = [NotificationKey.UserInfoKeys.type : LocalNotificationType.backgroundFetch.rawValue]
                        let content = UNMutableNotificationContent()
                        content.body = notificationText
                        if error {
                            userInfo[NotificationKey.UserInfoKeys.from] = range.from
                            content.userInfo = userInfo
                            content.categoryIdentifier = NotificationKey.CategoryKeys.retry
                            return UNNotificationRequest(identifier: localNotificationRequestIdentifier, content: content, trigger: nil)
                        }
                        if range.to < cftvc.numberOfRequest {
                            content.categoryIdentifier = NotificationKey.CategoryKeys.fetch
                            userInfo[NotificationKey.UserInfoKeys.from] = range.to
                            content.userInfo = userInfo
                        }
                        if signed {
                            content.sound = UNNotificationSound.default
                        }
                        return UNNotificationRequest(identifier: localNotificationRequestIdentifier, content: content, trigger: nil)
                    }()
                    UNUserNotificationCenter.current().getDeliveredNotifications { (deliveredNotificationArray) in
                        let maximumNotification = 3
                        if deliveredNotificationArray.count >= maximumNotification {
                            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [deliveredNotificationArray.last!.request.identifier])
                        }
                        UNUserNotificationCenter.current().add(notificationRequest)
                        completionHandler?(signingStatusArray.first {$0.status == .error} != nil ? .failed : .newData)
                    }
                }
            }
        }
    }

    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard PreferencesManager.shared.isBackgroundFetchingOn else {
            completionHandler(.noData)
            return
        }
        let fetchGroup = DispatchGroup()
        var dataFlag: UIBackgroundFetchResult = .noData
        
        defer {
            fetchGroup.notify(queue: .main) {
                completionHandler(dataFlag)
            }
        }

        if PreferencesManager.shared.monitorSigningStatus {
            fetchGroup.enter()
            fetchingSigningAtBackground(range: (0, numOfRequestsFetchedOne)) { result in
                DispatchQueue.main.sync {
                    dataFlag = dataFlag == .failed ? .failed : (result == .failed ? .failed : .newData)
                }
                fetchGroup.leave()
            }
        }
        if PreferencesManager.shared.fetchSHSHBlobsBackground {
            guard PreferencesManager.shared.nextBlobsFetchingDate == nil || PreferencesManager.shared.nextBlobsFetchingDate! <= Date() else {
                if PreferencesManager.shared.verboseNotification {
                    fetchGroup.enter()
                    let content = UNMutableNotificationContent()
                    content.body = "Skip checking latest version. Next fetch schedule: \(PreferencesManager.shared.nextBlobsFetchingDate!.description(with: .current))"
                    let request = UNNotificationRequest(identifier: "Notification_\(Date().timeIntervalSinceNow)", content: content, trigger: nil)
                    UNUserNotificationCenter.current().add(request) { _ in
                        fetchGroup.leave()
                    }
                }
                return
            }
            fetchGroup.enter()
            let blobSavingGroup = DispatchGroup()
            let otherProfiles = PreferencesManager.shared.profiles
            let profiles: [DeviceProfile] = {
                var p = [DeviceProfile.local]
                if otherProfiles.isEmpty == false {
                    p.append(contentsOf: otherProfiles[0..<min(2, otherProfiles.count)])
                }
                return p
            }()
            struct FetchInfo {
                var result: Bool
                var message: String?
            }
            let apnonceDatabase = NSDictionary(contentsOfFile: GlobalConstants.customAPNonceGenListFilePath) as? [String : [[String : String]]] ?? [:]

            var results = [String : FetchInfo]()
            profiles.forEach { profile in
                guard let _ecidString = profile.ecid, let profileECID = TSSECID(string: _ecidString) else {
                    results[profile.deviceModel] = FetchInfo(result: false, message: "Missing ECID")
                    return
                }
                struct CustomNonce {
                    var apnonce: TSSAPNonce?
                    //                var sepnonce: TSSSEPNonce?
                    var generator: TSSGenerator?
                }
                guard let customAPNonceList: [CustomNonce] = {
                    var c = apnonceDatabase[profile.apnonceDatabaseProfileKey]?.compactMap { dict -> CustomNonce? in
                        var nonce = CustomNonce()
                        if let apnonceText = dict[CustomAPGenKey.APNonce_Key] {
                            nonce.apnonce = try? TSSAPNonce(nonceString: apnonceText, deviceModel: profile.deviceModel)
                        }
                        //                if let sepnonceText = dict[CustomAPGenKey.SEPNonce_Key] {
                        //                    nonce.sepnonce = try? TSSSEPNonce(nonceString: sepnonceText, deviceModel: profile.deviceModel)
                        //                }
                        if let generatorText = dict[CustomAPGenKey.Generator_Key] {
                            nonce.generator = try? TSSGenerator(string: generatorText)
                        }
                        if nonce.apnonce == nil && nonce.generator == nil {
                            return nil
                        }
                        return nonce
                    } ?? []
                    if TSSNonce.isNonceEntanglingEnabled(forDeviceModel: profile.deviceModel) {
                        // remove trivial entries
                        c.removeAll {
                            $0.apnonce == nil || $0.generator == nil
                        }
                        if c.isEmpty {
                            return nil
                        }
                    }
                    return c
                }() else {
                    // nonce - generator pair is required for A12+ to save valid blobs
                    results[profile.deviceModel] = .init(result: false, message: "Missing nonce pair")
                    return
                }
                blobSavingGroup.enter()
                // fetch firmware info from remote
                var request = URLRequest(url: URL(string: "https://api.ipsw.me/v4/device/\(profile.deviceModel)")!)
                request.addValue("application/json", forHTTPHeaderField: "Accept")
                request.timeoutInterval = 10
                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    #if DEBUG
                    if let error = error {
                        DispatchQueue.main.sync {
                            results[profile.deviceModel] = FetchInfo(result: false, message: "Network error")
                            print("BF_Error: \(error.localizedDescription)")
                        }
                        blobSavingGroup.leave()
                        return
                    }
                    #else
                    if error != nil {
                        DispatchQueue.main.sync {
                            results[profile.deviceModel] = FetchInfo(result: false, message: "Network error")
                        }
                        blobSavingGroup.leave()
                        return
                    }
                    #endif
                    
                    guard let data = data, let loadedDictionary = (((try? JSONSerialization.jsonObject(with: data)) as? [String : Any])?[JsonKeys.firmwares_Key]) as? [[String : Any]] else {
                        DispatchQueue.main.sync {
                            results[profile.deviceModel] = .init(result: false, message: "Parse error")
                        }
                        blobSavingGroup.leave()
                        return
                    }
                    
                    let signedVersionArray = loadedDictionary.filter {$0[JsonKeys.signed_Key] as? Bool ?? false}.compactMap { dict -> Version? in
                        if let str = dict[JsonKeys.version_Key] as? String, let urlStr = dict[JsonKeys.url_Key] as? String, let id = dict[JsonKeys.buildid_Key] as? String {
                            return Version(versionString: str, buildID: id, firmwareURLString: urlStr)
                        }
                        return nil
                    }
                    // get current latest version
                    guard let latestVersion = signedVersionArray.max() else {
                        DispatchQueue.main.sync {
                            results[profile.deviceModel] = .init(result: false, message: "Parse error")
                        }
                        blobSavingGroup.leave()
                        return
                    }
                    let saved = (try? FileManager.default.contentsOfDirectory(atPath: profile.blobsDirectoryPath!).contains { (fileName) -> Bool in
                        fileName.contains(latestVersion.buildID) && fileName.contains(latestVersion.buildNumber)
                        }) ?? false
                    guard saved == false else {
                        DispatchQueue.main.sync {
                            results[profile.deviceModel] = .init(result: true, message: PreferencesManager.shared.verboseNotification ? "\(latestVersion.buildNumber) already saved" : nil)
                        }
                        blobSavingGroup.leave()
                        return
                    }
                    let tssrequest = TSSRequest(firmwareURL: latestVersion.firmwareURLString, deviceBoardConfiguration: profile.deviceBoard, ecid: profileECID)
                    let timeout: TimeInterval = 10
                    var shouldContinue = true
                    let timer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
                        shouldContinue = false
                        tssrequest.cancel()
                    }
                    if customAPNonceList.isEmpty == false {
                        var successCount = 0
                        for nonce_tuple in customAPNonceList {
                            if shouldContinue == false {
                                break
                            }
                            tssrequest.apnonce = nonce_tuple.apnonce
                            tssrequest.generator = nonce_tuple.generator
                            if let _ = try? tssrequest.downloadSHSHBlobs(atDirectory: profile.blobsDirectoryPath!) {
                                successCount += 1
                            }
                        }
                        DispatchQueue.main.sync {
                            if successCount > 0 {
                                results[profile.deviceModel] = .init(result: true, message: "Saved \(successCount) blob\(successCount == 1 ? "" : "s") for \(latestVersion.buildNumber)")
                            }
                            else {
                                results[profile.deviceModel] = .init(result: false, message: "Request error")
                            }
                        }
                        blobSavingGroup.leave()
                    }
                    else {
                        tssrequest.downloadSHSHBlobs(atDirectory: profile.blobsDirectoryPath!) { (fileName, error) in
                            DispatchQueue.main.sync {
                                if fileName != nil {
                                    results[profile.deviceModel] = .init(result: true, message: "Saved blob for \(latestVersion.buildNumber)")
                                }
                                else {
                                    results[profile.deviceModel] = .init(result: false, message: "Request error")
                                }
                            }
                            blobSavingGroup.leave()
                        }
                    }
                    timer.invalidate()
                }
                task.resume()
            }
            blobSavingGroup.notify(queue: DispatchQueue.main) {
                // notification
                var contentBody = ""
                var errorFlag = false
                results.forEach { (key, value) in
                    guard let message = value.message else { return }
                    contentBody += "\(value.result ? "✅" : "⚠️")\(key): \(message)\n"
                    if value.result == false {
                        errorFlag = true
                    }
                }
                if errorFlag == false {
                    // check latest version every 5 days
                    let interval: TimeInterval = 5 * 24 * 3600
                    if var date = PreferencesManager.shared.nextBlobsFetchingDate {
                        date.addTimeInterval(interval)
                        PreferencesManager.shared.nextBlobsFetchingDate = date
                    }
                    else {
                        PreferencesManager.shared.nextBlobsFetchingDate = Date().addingTimeInterval(interval)
                    }
                    #if DEBUG
                    print("next fetch schedule: \(PreferencesManager.shared.nextBlobsFetchingDate?.description(with: .current) ?? "nil")")
                    #endif
                }
                guard contentBody.isEmpty == false else {
                    DispatchQueue.global().async {
                        fetchGroup.leave()
                    }
                    return
                }
                contentBody.removeLast()
                let notificationId = "Notification_\(Date().timeIntervalSinceNow)_blob_save"
                let content = UNMutableNotificationContent()
                content.body = contentBody
                content.sound = .default
                UNUserNotificationCenter.current().add(.init(identifier: notificationId, content: content, trigger: nil)) { _ in
                    fetchGroup.leave()
                }
            }
        }
    }
}
extension AppDelegate : UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        let userInfo = response.notification.request.content.userInfo
        if let from = userInfo[NotificationKey.UserInfoKeys.from] as? Int {
            fetchingSigningAtBackground(range: (from, from + numOfRequestsFetchedOne)) { _ in
                completionHandler()
            }
        }
        else {
            completionHandler()
        }
    }

//    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
//        completionHandler([.alert, .badge, .sound])
//    }
}
fileprivate struct Version : Comparable, Equatable {
    static func < (lhs: Version, rhs: Version) -> Bool {
        if lhs.major == rhs.major {
            if lhs.minor == rhs.minor {
                return lhs.patch < lhs.patch
            }
            return lhs.minor < rhs.minor
        }
        return lhs.major < rhs.major
    }
    var major: Int
    var minor: Int
    var patch: Int
    var firmwareURLString: String
    var buildID: String
    var buildNumber: String {
        if patch != 0 {
            return "\(major).\(minor).\(patch)"
        }
        return "\(major).\(minor)"
    }
    
}
extension Version {
    init(versionString: String, buildID: String, firmwareURLString: String) {
        let splitArray = versionString.components(separatedBy: ".")
        major = Int(splitArray[0])!
        minor = Int(splitArray[1])!
        patch = splitArray.count > 2 ? Int(splitArray[2])! : 0
        self.firmwareURLString = firmwareURLString
        self.buildID = buildID
    }
}
