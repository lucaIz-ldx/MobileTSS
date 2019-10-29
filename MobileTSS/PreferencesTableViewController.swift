//
//  PreferencesTableViewController.swift
//  MobileTSS
//
//  Created by User on 7/18/18.
//

import UIKit

class PreferencesTableViewController: UITableViewController {
    
    @IBOutlet private weak var currentECIDLabel: UILabel!
    @IBOutlet private weak var deviceModelLabel: UILabel!
    @IBOutlet private weak var deviceBoardLabel: UILabel!
    
    //    @IBOutlet private weak var certIDLabel: UILabel!
    //    @IBOutlet private weak var bbsnumSizeLabel: UILabel!
    
    @IBOutlet private weak var backgroundFetchSwitch: UISwitch!
    @IBOutlet private weak var fetchIntervalLabel: UILabel!
    
    @IBOutlet private weak var expirationNotificationSwitch: UISwitch!
    @IBOutlet private weak var expirationDateLabel: UILabel!
    
    @IBOutlet private weak var showUnsignedFirmwareSwitch: UISwitch!

    override func viewDidLoad() {
        super.viewDidLoad()
        if let ecid = TSSRequest.localECID {
            self.currentECIDLabel.text = ecid.isEmpty ? "Not set" : ecid
        }
        self.deviceModelLabel.text = GlobalConstants.localProductType
        self.deviceBoardLabel.text = GlobalConstants.localDeviceBoard
        self.backgroundFetchSwitch.isOn = PreferencesManager.shared.isBackgroundFetchingOn
        self.fetchIntervalLabel.text = PreferencesManager.FetchInterval.allValues[PreferencesManager.shared.fetchIntervalAtIndex].description
        
        self.showUnsignedFirmwareSwitch.isOn = PreferencesManager.shared.isShowingUnsignedFirmware
        //        self.certIDLabel.text = String(getLocalDeviceInfo().pointee.basebandCertID)
        //        self.bbsnumSizeLabel.text = String(getLocalDeviceInfo().pointee.bbsnumSize)
        self.expirationNotificationSwitch.isOn = PreferencesManager.shared.isExpirationNotificationOn
        if let date = AppDelegate.expirationDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            self.expirationDateLabel.text = dateFormatter.string(from: date)
            if date.timeIntervalSinceNow < 24*3600 {
                self.expirationDateLabel.textColor = UIColor.red
            }
        }
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.deselectRow(at: IndexPath(row: 1, section: 2), animated: true)
    }
    // MARK: - Helpers
    private func createEditingPrompt(title: String, message: String, textFieldConfiguration: @escaping (UITextField) -> Void, proceedHandler: @escaping ((UIAlertController) -> Void)) -> Void {
        let editView = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        editView.addTextField(configurationHandler: textFieldConfiguration)
        editView.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        editView.addAction(UIAlertAction(title: "OK", style: .default, handler: { [unowned editView] (_) in
            proceedHandler(editView)
        }))
        self.present(editView, animated: true)
    }
    
    // MARK: - Actions
    @IBAction private func tapToEditECID(_ sender: UITapGestureRecognizer) {
        createEditingPrompt(title: "Enter ECID", message: "Enter ECID for saving SHSH blobs. ", textFieldConfiguration: { (textField) in
            if let numericECID = (sender.view as! UILabel).text, Int(numericECID) != nil {
                textField.text = numericECID
            }
            textField.clearButtonMode = .always
            textField.placeholder = "ECID (Hex/Dec): "
            textField.keyboardType = .asciiCapable
            textField.returnKeyType = .done
        }, proceedHandler: { (alertViewController) in
            let ecidString: String = (alertViewController.textFields?.first?.text)!
            if (!TSSRequest.setECIDToPreferences(ecidString)) {
                let errorView = UIAlertController(title: LocalizedString.errorTitle, message: "Failed to parse ECID. Make sure you've entered a valid ECID", preferredStyle: .alert)
                errorView.addAction(UIAlertAction(title: "OK", style: .default, handler: { (_) in
                    self.present(alertViewController, animated: true)
                }))
                self.present(errorView, animated: true)
            }
            else {
                self.currentECIDLabel.text = TSSRequest.localECID!
            }
        })
    }
/*
    @IBAction private func tapToEditBasebandCertID(_ sender: UITapGestureRecognizer) {
        guard let label = (sender.view as? UILabel) else { fatalError("UILabel expected.") }
        createEditingPrompt(title: "Enter Cert ID", message: "Please enter baseband certificate ID.", textFieldConfiguration: { (textField) in
            if let numericID = label.text, UInt64(numericID) != nil {
                textField.text = numericID
            }
            textField.clearButtonMode = .always
            textField.placeholder = "Baseband Cert ID"
            textField.keyboardType = .numberPad
            textField.returnKeyType = .done
        }, proceedHandler: { (alertViewController) in
            let idString: String = (alertViewController.textFields?.first?.text)!
            if let parsedID = UInt64(idString) {
                setLocalDeviceBasebandCertID(parsedID)
                label.text = idString
            }
            else {
                label.text = "0"
            }
        })
    }

    @IBAction private func tapToEditBasebandSerialNumberSize(_ sender: UITapGestureRecognizer) {
        guard let label = (sender.view as? UILabel) else { fatalError("UILabel expected.") }
        createEditingPrompt(title: "Enter BbsnumSize", message: "Please enter baseband serial number size.", textFieldConfiguration: { (textField) in
            if let numericID = (sender.view as? UILabel)?.text, UInt64(numericID) != nil {
                textField.text = numericID
            }
            textField.clearButtonMode = .always
            textField.placeholder = "BbsnumSize"
            textField.keyboardType = .numberPad
            textField.returnKeyType = .done
        }, proceedHandler: { (alertViewController) in
            let idString: String = (alertViewController.textFields?.first?.text)!
            if let parsedID = UInt64(idString) {
                setLocalDeviceBasebandCertID(parsedID)
                label.text = idString
            }
            else {
                label.text = "0"
            }
        })
    }
*/
    @IBAction private func clearCachesWithButton(_ sender: UIButton) {
        let tempDirectoryContent = try? FileManager.default.contentsOfDirectory(atPath: GlobalConstants.buildManifestDirectoryPath)
        var clearedSize: UInt64 = 0
        tempDirectoryContent?.forEach { (cacheName) in
            do {
                let cacheFilePath = GlobalConstants.buildManifestDirectoryPath + cacheName
                let fileSize = (try FileManager.default.attributesOfItem(atPath: cacheFilePath) as NSDictionary).fileSize()
                
                try FileManager.default.removeItem(atPath: cacheFilePath)
                clearedSize += fileSize
            } catch let error as NSError {
                print("\(error.localizedDescription)")
            }
        }
        let formatedSize = String(format: "%.02f %@B", (Double(clearedSize) / 1024.0 / (clearedSize > 1024 * 1000 ? 1024 : 1)), (clearedSize > 1024 * 1000) ? "M" : "K")
        let clearAlertView = UIAlertController(title: "", message: "Cleared \(formatedSize).", preferredStyle: .alert)
        clearAlertView.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(clearAlertView, animated: true)
    }
    @IBAction private func unsignedSwitchTriggered(_ sender: UISwitch) {
        PreferencesManager.shared.isShowingUnsignedFirmware = sender.isOn
        NotificationCenter.default.post(name: .ShowUnsignedFirmwarePreferenceChanged, object: self)
    }
    @IBAction private func backgroundFetchTriggered(_ sender: UISwitch) {
        if UIApplication.shared.backgroundRefreshStatus != .available && sender.isOn {
            let errorView = UIAlertController(title: LocalizedString.errorTitle, message: "Background Refresh is not available. Please turn it on in Settings before enabling background fetching. ", preferredStyle: .alert)
            errorView.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(errorView, animated: true) {
                sender.isOn = false
            }
            return
        }
        PreferencesManager.shared.isBackgroundFetchingOn = sender.isOn
        // magic
        self.tableView.reloadRows(at: [IndexPath(row: 0, section: 1)], with: .none)
    }
    @IBAction private func expirationNotificationSwitchTriggered(_ sender: UISwitch) {
        PreferencesManager.shared.isExpirationNotificationOn = sender.isOn
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let fivc = segue.destination as? FetchIntervalTableViewController {
            fivc.currentSelectedIndex = PreferencesManager.shared.fetchIntervalAtIndex
            fivc.selectedIndexCallback = { selectedIndex in
                PreferencesManager.shared.fetchIntervalAtIndex = selectedIndex
                let interval = PreferencesManager.FetchInterval.allValues[selectedIndex]
                self.fetchIntervalLabel.text = interval.description
                UIApplication.shared.setMinimumBackgroundFetchInterval(TimeInterval(interval == PreferencesManager.FetchInterval.allValues.last! ? UIApplicationBackgroundFetchIntervalMinimum : TimeInterval(interval.rawValue)))
            }
        }
    }
}
extension PreferencesTableViewController {
    // MARK: - Table View Methods
    private func hideSection(_ section: Int) -> Bool {
        let expirationSection = 2
        if section == expirationSection && AppDelegate.expirationDate == nil {
            return true
        }
        return false
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return hideSection(section) ? 0 : super.tableView(tableView, numberOfRowsInSection: section)
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return hideSection(section) ? nil : super.tableView(tableView, titleForHeaderInSection: section)
    }
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return hideSection(section) ? CGFloat.leastNonzeroMagnitude : super.tableView(tableView, heightForHeaderInSection: section)
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return hideSection(section) ? CGFloat.leastNonzeroMagnitude : super.tableView(tableView, heightForFooterInSection: section)
    }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return hideSection(section) ? nil : super.tableView(tableView, titleForFooterInSection: section)
    }
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 1 && indexPath.row == 1 && PreferencesManager.shared.isBackgroundFetchingOn == false {
            return 0
        }
        return super.tableView(tableView, heightForRowAt: indexPath)
    }
}
@objc
class PreferencesManager : NSObject {
    private struct PreferencesKeys {
        struct PreferencesBit: OptionSet {
            let rawValue: Int
            static let showingUnsignedFirmware = PreferencesBit(rawValue: 1 << 0)
            static let expirationNotfication = PreferencesBit(rawValue: 1 << 1)
            static let backgroundFetching = PreferencesBit(rawValue: 1 << 2)
            static let reserved = PreferencesBit(rawValue: 1 << 6)
        }
        static let preferencesBitData_Key = "Preferences data"
    }
    enum FetchInterval: Int, CustomStringConvertible {
        case One_Day = 86400
        case Twelve_Hours = 43200
        case Eight_Hours = 28800
        case Four_Hours = 14400
        case Two_Hours = 7200
        case One_Hour = 3600
        case Minimum = 0
        var description: String {
            let hours = self.rawValue / 3600
            return hours != 0 ? "\(hours) Hour\(hours == 1 ? "" : "s")" : "Minimum"
        }
        static let allValues: [FetchInterval] = [One_Day, Twelve_Hours, Eight_Hours, Four_Hours, Two_Hours, One_Hour, Minimum]
    }

    @objc static let shared = PreferencesManager()
    private var preferencesBit: PreferencesKeys.PreferencesBit = PreferencesKeys.PreferencesBit(rawValue: getPreferences(for: PreferencesKeys.preferencesBitData_Key) as? Int ?? 0) {
        didSet {
            PreferencesManager.setPreferences(value: preferencesBit.rawValue, forKey: PreferencesKeys.preferencesBitData_Key)
        }
    }
    fileprivate(set) var isShowingUnsignedFirmware: Bool {
        get {
            return preferencesBit.contains(PreferencesKeys.PreferencesBit.showingUnsignedFirmware)
        }
        set {
            if (newValue) {
                preferencesBit.insert(PreferencesKeys.PreferencesBit.showingUnsignedFirmware)
            }
            else {
                preferencesBit.remove(PreferencesKeys.PreferencesBit.showingUnsignedFirmware)
            }
        }
    }
    fileprivate(set) var isExpirationNotificationOn: Bool {
        get {
            return preferencesBit.contains(PreferencesKeys.PreferencesBit.expirationNotfication)
        }
        set {
            var preferences = preferencesBit
            if (newValue) {
                AppDelegate.registerNotificationPermission()
                preferences.insert(PreferencesKeys.PreferencesBit.expirationNotfication)
            }
            else {
                AppDelegate.cancelExpirationNotification()
                preferences.remove(PreferencesKeys.PreferencesBit.expirationNotfication)
            }
        }
    }
    fileprivate(set) var isBackgroundFetchingOn: Bool {
        get {
            return preferencesBit.contains(PreferencesKeys.PreferencesBit.backgroundFetching)
        }
        set {
            if (newValue) {
                AppDelegate.registerNotificationPermission()
                preferencesBit.insert(PreferencesKeys.PreferencesBit.backgroundFetching)
                let interval: TimeInterval = TimeInterval(FetchInterval.allValues[fetchIntervalAtIndex].rawValue)
                UIApplication.shared.setMinimumBackgroundFetchInterval(interval)
            }
            else {
                preferencesBit.remove(PreferencesKeys.PreferencesBit.backgroundFetching)
                UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalNever)
            }
        }
    }
    fileprivate(set) var fetchIntervalAtIndex: Int {
        get {
            return (preferencesBit.rawValue & 0b111000) >> 3
        }
        set {
            assert(newValue >= 0 && newValue < FetchInterval.allValues.count)
            preferencesBit = PreferencesKeys.PreferencesBit(rawValue: (preferencesBit.rawValue & ~0b111000) | (newValue << 3))
        }
    }
    fileprivate(set) var requestTimeout: Int = getPreferences(for: TSSTimeoutPreferencesKey) as? Int ?? 7 {
        didSet {
            PreferencesManager.setPreferences(value: requestTimeout, forKey: TSSTimeoutPreferencesKey)
        }
    }
    #if DEBIAN_PACKAGE
    private override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(synchronize), name: .UIApplicationWillResignActive, object: UIApplication.shared)
    }
    private var modified: Bool = false
    private var database: NSMutableDictionary = NSMutableDictionary.init(contentsOfFile: GlobalConstants.preferencesFilePath) ?? NSMutableDictionary()
    private static func setPreferences(value: Any?, forKey key: String) {
        PreferencesManager.shared.database[key] = value
        PreferencesManager.shared.modified = true
    }
    private static func getPreferences(for key: String) -> Any? {
        return PreferencesManager.shared.database[key]
    }
    @objc var ecidString: String? {
        get {
            return database["ECID"] as? String
        }
        set {
            database["ECID"] = newValue
        }
    }
    @objc func synchronize() {
        if modified {
            database.write(toFile: GlobalConstants.preferencesFilePath, atomically: true)
            modified = false
        }
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    #else
    private override init() {
        super.init()
    }
    private static func setPreferences(value: Any?, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
    private static func getPreferences(for key: String) -> Any? {
        return UserDefaults.standard.object(forKey: key)
    }
    #endif
}
