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
    
    @IBOutlet private weak var showUnsignedFirmwareSwitch: UISwitch!

    @IBOutlet private weak var versionLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        reloadDeviceInfoSection()
        showUnsignedFirmwareSwitch.isOn = PreferencesManager.shared.isShowingUnsignedFirmware
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDeviceInfoSection), name: .DeviceProfileHasChangedNotification, object: nil)
        versionLabel.text = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
    
    @objc private func reloadDeviceInfoSection() {
        let profile = PreferencesManager.shared.preferredProfile
        if let ecid = profile.ecid, ecid.isEmpty == false {
            currentECIDLabel.text = ecid
        }
        else {
            currentECIDLabel.text = "Not set"
        }
        deviceModelLabel.text = profile.deviceModel
        deviceBoardLabel.text = profile.deviceBoard
    }
    
    // MARK: - Actions
    @IBAction private func tapToEditECID(_ sender: UITapGestureRecognizer) {
        let editECIDView = UIAlertController(title: "Enter ECID", message: "Enter ECID for device \(deviceModelLabel.text ?? "") (\(deviceBoardLabel.text ?? "Unknown")). ", preferredStyle: .alert)
        editECIDView.addTextField { (textField) in
            if let numericECID = (sender.view as! UILabel).text, Int(numericECID) != nil {
                textField.text = numericECID
            }
            textField.clearButtonMode = .always
            textField.placeholder = "ECID (Hex/Dec): "
            textField.keyboardType = .asciiCapable
            textField.returnKeyType = .done
        }
        editECIDView.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        editECIDView.addAction(UIAlertAction(title: "OK", style: .default) { [unowned editECIDView] _ in
            let ecidString = editECIDView.textFields?.first?.text
            let isEmptyString = ecidString?.isEmpty ?? true
            let parsedECID = isEmptyString ? nil : TSSECID(string: ecidString!)?.ecidString
            if isEmptyString || parsedECID != nil {
                if let index = PreferencesManager.shared.currentProfileIndex {
                    var profile = PreferencesManager.shared.preferredProfile
                    profile.updateECID(parsedECID)
                    self.updateProfile(profile, at: index)
                }
                else {
                    DeviceProfile.setlocalECID(parsedECID)
                }
                self.currentECIDLabel.text = isEmptyString ? "Not set" : parsedECID
            }
            else {
                let errorView = UIAlertController(title: LocalizedString.errorTitle, message: "Failed to parse ECID. Make sure you've entered a valid ECID", preferredStyle: .alert)
                errorView.addAction(UIAlertAction(title: "OK", style: .default, handler: { (_) in
                    self.present(editECIDView, animated: true)
                }))
                self.present(errorView, animated: true)
            }
        })
        present(editECIDView, animated: true)
    }

    @IBAction private func clearCachesWithButton(_ sender: UIButton) {
        let tempDirectoryContent = try? FileManager.default.contentsOfDirectory(atPath: GlobalConstants.buildManifestDirectoryPath)
        var clearedSize: UInt64 = 0
        tempDirectoryContent?.forEach { (cacheName) in
            let cacheFilePath = GlobalConstants.buildManifestDirectoryPath + cacheName
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: cacheFilePath) as NSDictionary)?.fileSize() ?? 0
            clearedSize += fileSize
        }
        let formattedSize = String(format: "%.02f %@B", (Double(clearedSize) / 1024.0 / (clearedSize > 1024 * 1000 ? 1024 : 1)), (clearedSize > 1024 * 1000) ? "M" : "K")
        let clearWarningAlert = UIAlertController(title: "Clear cache", message: "Do you want to remove all downloaded buildmanifests? This operation will free \(formattedSize).", preferredStyle: .alert)
        clearWarningAlert.addAction(UIAlertAction(title: "No", style: .cancel))
        clearWarningAlert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { (_) in
            tempDirectoryContent?.forEach { path in
                try? FileManager.default.removeItem(atPath: GlobalConstants.buildManifestDirectoryPath + path)
            }
        }))
        present(clearWarningAlert, animated: true)
        
        // apnonce database cleanup
        DispatchQueue.global(qos: .background).async {
            guard var database = NSDictionary(contentsOfFile: GlobalConstants.customAPNonceGenListFilePath) as? [String : Any] else {return}
            database.removeValue(forKey: DeviceProfile.Local_Key)
            let validKeys = Set(PreferencesManager.shared.profiles.compactMap { profile -> String? in
                if profile.ecid == nil {
                    return nil
                }
                return profile.apnonceDatabaseProfileKey
            })
            let dirtyKeys = Set(database.keys).subtracting(validKeys)
            guard dirtyKeys.isEmpty == false else {return}
            let cleaned = database.filter {!dirtyKeys.contains($0.key)}
            (cleaned as NSDictionary).write(toFile: GlobalConstants.customAPNonceGenListFilePath, atomically: true)
        }
    }
    @IBAction private func unsignedSwitchTriggered(_ sender: UISwitch) {
        PreferencesManager.shared.isShowingUnsignedFirmware = sender.isOn
        NotificationCenter.default.post(name: .ShowUnsignedFirmwarePreferenceChanged, object: self)
    }
}


