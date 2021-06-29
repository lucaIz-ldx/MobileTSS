//
//  PreferencesManager.swift
//  MobileTSS
//
//  Created by Luca on 6/8/21.
//

import UIKit
import UserNotifications

class PreferencesManager {
    enum FetchInterval: Int, CustomStringConvertible, CaseIterable {
        case One_Day = 86400
        case Twelve_Hours = 43200
        case Eight_Hours = 28800
        case Four_Hours = 14400
        case Two_Hours = 7200
        case One_Hour = 3600
        case Minimum = 0
        var description: String {
            let hours = rawValue / 3600
            return hours != 0 ? "\(hours) Hour\(hours == 1 ? "" : "s")" : "Minimum"
        }
        var intervalValue: TimeInterval {
            switch self {
                case .Minimum:
                    return UIApplication.backgroundFetchIntervalMinimum
                default:
                    return TimeInterval(self.rawValue)
            }
        }
    }

    static let shared = PreferencesManager()

    var isShowingUnsignedFirmware: Bool {
        get {
            return preferencesBit.contains(PreferencesKey.PreferencesBit.showingUnsignedFirmware)
        }
        set {
            if (newValue) {
                preferencesBit.insert(PreferencesKey.PreferencesBit.showingUnsignedFirmware)
            }
            else {
                preferencesBit.remove(PreferencesKey.PreferencesBit.showingUnsignedFirmware)
            }
        }
    }

    var isBackgroundFetchingOn: Bool {
        get {
            return preferencesBit.contains(PreferencesKey.PreferencesBit.backgroundFetching)
        }
        set {
            if (newValue) {
                UNUserNotificationCenter.current().getNotificationSettings { (settings) in
                    if settings.authorizationStatus == .notDetermined {
                        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
                        }
                    }
                }
                preferencesBit.insert(PreferencesKey.PreferencesBit.backgroundFetching)
                UIApplication.shared.setMinimumBackgroundFetchInterval(FetchInterval.allCases[fetchIntervalAtIndex].intervalValue)
            }
            else {
                preferencesBit.remove(PreferencesKey.PreferencesBit.backgroundFetching)
                UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalNever)
            }
        }
    }
    var fetchIntervalAtIndex: Int {
        get {
            return (preferencesBit.rawValue & 0b111000) >> 3
        }
        set {
            assert(newValue >= 0 && newValue < FetchInterval.allCases.count)
            preferencesBit = PreferencesKey.PreferencesBit(rawValue: (preferencesBit.rawValue & ~0b111000) | (newValue << 3))
            UIApplication.shared.setMinimumBackgroundFetchInterval(FetchInterval.allCases[newValue].intervalValue)
        }
    }
    var fetchSHSHBlobsBackground: Bool {
        get {
            return preferencesBit.contains(.fetchSHSHBlob_BF)
        }
        set {
            if newValue {
                preferencesBit.insert(.fetchSHSHBlob_BF)
            }
            else {
                preferencesBit.remove(.fetchSHSHBlob_BF)
            }
        }
    }
    var verboseNotification: Bool {
        get {
            return preferencesBit.contains(.verboseNotification_BF)
        }
        set {
            if newValue {
                preferencesBit.insert(.verboseNotification_BF)
            }
            else {
                preferencesBit.remove(.verboseNotification_BF)
            }
        }
    }
    var monitorSigningStatus: Bool {
        get {
            return preferencesBit.contains(.monitorSigningStatus_BF)
        }
        set {
            if newValue {
                preferencesBit.insert(.monitorSigningStatus_BF)
            }
            else {
                preferencesBit.remove(.monitorSigningStatus_BF)
            }
        }
    }
    
    var currentProfileIndex: Int? {
        didSet {
            guard oldValue != currentProfileIndex else { return }
            setPreferences(value: currentProfileIndex, forKey: PreferencesKey.current_profile_Key)
        }
    }
    // no guarantee that blobs will be fetch on that date but
    var nextBlobsFetchingDate: Date? {
        didSet {
            setPreferences(value: nextBlobsFetchingDate, forKey: PreferencesKey.nextFetchDateKey)
        }
    }

    // only store custom profile
    fileprivate(set) var profiles: [DeviceProfile] {
        didSet {
            setPreferences(value: profiles.map({$0.archivedDictionary}), forKey: PreferencesKey.profiles_Key)
        }
    }
    

    var preferredProfile: DeviceProfile {
        return currentProfileIndex == nil ? DeviceProfile.local : profiles[currentProfileIndex!]
    }
    
    // MARK: private propertities
    private var preferencesBit: PreferencesKey.PreferencesBit {
        didSet {
            setPreferences(value: preferencesBit.rawValue, forKey: PreferencesKey.preferencesBitData_Key)
        }
    }

    private init() {
        preferencesBit = PreferencesKey.PreferencesBit(rawValue: UserDefaults.standard.object(forKey: PreferencesKey.preferencesBitData_Key) as? Int ?? 0)

        let profileDictionaryArray = UserDefaults.standard.object(forKey: PreferencesKey.profiles_Key) as? [[String : String]] ?? []
        profiles = profileDictionaryArray.compactMap {DeviceProfile(archivedDictionary: $0)}
        nextBlobsFetchingDate = UserDefaults.standard.object(forKey: PreferencesKey.nextFetchDateKey) as? Date
        if let currIndex = UserDefaults.standard.object(forKey: PreferencesKey.current_profile_Key) as? Int,
            profiles.count > currIndex {
            currentProfileIndex = currIndex
        }
        else {
            currentProfileIndex = nil
        }
    }
    private func setPreferences(value: Any?, forKey key: String) {
        if value != nil {
            UserDefaults.standard.set(value, forKey: key)
        }
        else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
    private func getPreferences(forKey key: String) -> Any? {
        return UserDefaults.standard.object(forKey: key)
    }
}
extension AppDelegate {
//    struct ShortcutKeys {
//        <#fields#>
//    }
    static let CustomProfileShortcutType = Bundle.main.bundleIdentifier! + ".custom.profile"
    static let LocalProfileShortcutType = Bundle.main.bundleIdentifier! + ".local.profile"
    static let ProfileLocalIndexInfoKey = Bundle.main.bundleIdentifier! + ".userinfo.profileIndex"
    static let LocalProfileShortcutLocalizedTitle = "Local profile"

    @discardableResult
    func updateProfileViaShortcutItem(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        if shortcutItem.type == AppDelegate.LocalProfileShortcutType {
            PreferencesManager.shared.currentProfileIndex = nil
        }
        else if let userInfo = shortcutItem.userInfo as? [String : Int], let index = userInfo[AppDelegate.ProfileLocalIndexInfoKey] {
            if (0..<PreferencesManager.shared.profiles.count).contains(index) {
                PreferencesManager.shared.currentProfileIndex = index
            }
            else {
                // out of range; remove this shortcut.
                let indexToBeRemoved = UIApplication.shared.shortcutItems?.firstIndex(of: shortcutItem)
                UIApplication.shared.shortcutItems?.remove(at: indexToBeRemoved!)
                return false
            }
        }
        else if let userInfo = shortcutItem.userInfo as? [String : String] {
            // deprecated since we store profile as index
            if let deviceProfile = DeviceProfile(archivedDictionary: userInfo), let index = PreferencesManager.shared.profiles.firstIndex(where: {$0 == deviceProfile}) {
                PreferencesManager.shared.currentProfileIndex = index
            }
            else {
                // requested profile by shortcut cannot be found; remove this shortcut.
                let indexToBeRemoved = UIApplication.shared.shortcutItems?.firstIndex(of: shortcutItem)
                UIApplication.shared.shortcutItems?.remove(at: indexToBeRemoved!)
                return false
            }
        }
        else {
            return false
        }
        if let tabbarController = window?.rootViewController as? UITabBarController, let selectedVC = tabbarController.selectedViewController as? UINavigationController, let ptvc = selectedVC.viewControllers.first(where: {$0 is ProfilesTableViewController}) as? ProfilesTableViewController {
            ptvc.tableView.reloadData()
        }
        NotificationCenter.default.post(name: .DeviceProfileHasChangedNotification, object: self)
        return true
    }
}
extension PreferencesTableViewController {
    func updateProfile(_ profile: DeviceProfile, at index: Int) {
        PreferencesManager.shared.profiles[index] = profile
    }
}
extension ProfilesTableViewController {
    func saveProfile() {
        PreferencesManager.shared.profiles = profileList
        guard profileList.isEmpty == false else {
            UIApplication.shared.shortcutItems = nil
            return
        }
        let maxDynamicShortcutItems = 2     // this excludes "Local profile"

        var shortcutItems = profileList[0..<min(profileList.count, maxDynamicShortcutItems)].enumerated().map { (value) -> UIApplicationShortcutItem in
            let deviceProfile = value.element
            let item = UIApplicationShortcutItem(type: AppDelegate.CustomProfileShortcutType, localizedTitle: deviceProfile.deviceModel, localizedSubtitle: deviceProfile.ecid, icon: nil, userInfo: [AppDelegate.ProfileLocalIndexInfoKey : value.offset] as [String : NSSecureCoding])
            return item
        }
        let localShortcut = UIApplicationShortcutItem(type: AppDelegate.LocalProfileShortcutType, localizedTitle: AppDelegate.LocalProfileShortcutLocalizedTitle, localizedSubtitle: nil, icon: nil)

        shortcutItems.insert(localShortcut, at: 0)
        UIApplication.shared.shortcutItems = shortcutItems
    }
}
fileprivate struct PreferencesKey {
    struct PreferencesBit: OptionSet {
        let rawValue: Int
        static let showingUnsignedFirmware = PreferencesBit(rawValue: 1 << 0)
        //            static let expirationNotfication = PreferencesBit(rawValue: 1 << 1)
        static let backgroundFetching = PreferencesBit(rawValue: 1 << 2)
        // bit 3,4,5 stores fetch interval index
        static let fetchSHSHBlob_BF = PreferencesBit(rawValue: 1 << 6)
        static let monitorSigningStatus_BF = PreferencesBit(rawValue: 1 << 7)
        static let verboseNotification_BF = PreferencesBit(rawValue: 1 << 8)
        
        static let reserved = PreferencesBit(rawValue: 1 << 9)
    }
    static let preferencesBitData_Key = "Preferences data"
    static let profiles_Key = "Profiles"
    static let current_profile_Key = "Current Profile"
    static let nextFetchDateKey = "Next Fetch Date"
}
