//
//  ProfilesTableViewController.swift
//  MobileTSS
//
//  Created by User on 12/6/19.
//

import UIKit

class ProfilesTableViewController: UITableViewController {
    private var isModified = false
    private(set) var profileList: [DeviceProfile] = PreferencesManager.shared.profiles {
        didSet {
            isModified = true
        }
    }
    private var currentProfileIndex: Int? = PreferencesManager.shared.currentProfileIndex {
        didSet {
            selectedProfile = currentProfileIndex == nil ? DeviceProfile.local : profileList[currentProfileIndex!]
        }
    }
    private var selectedProfile: DeviceProfile = PreferencesManager.shared.preferredProfile
    // tableview will be happy if it is being layout when visible
    private var updateTableViewBlock: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView()
        NotificationCenter.default.addObserver(self, selector: #selector(saveData), name: UIApplication.willResignActiveNotification, object: UIApplication.shared)
        navigationItem.rightBarButtonItem = editButtonItem
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateTableViewBlock?()
        updateTableViewBlock = nil
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        saveData()
    }
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        if editing == false {
            saveData()
        }
        tableView.setEditing(editing, animated: animated)
    }
    @objc private func saveData() {
        let previousProfile = PreferencesManager.shared.preferredProfile
        if isModified {
            saveProfile()
            isModified = false
        }
        PreferencesManager.shared.currentProfileIndex = currentProfileIndex
        if selectedProfile != previousProfile {
            NotificationCenter.default.post(name: .DeviceProfileHasChangedNotification, object: self)
        }
    }
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section == 1 else {
            return 1
        }
        return profileList.count + 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 1 && indexPath.row == profileList.count {
            let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: "newcell", for: indexPath)

//            cell.imageView?.image = cell.imageView?.image?.withRenderingMode(.alwaysTemplate)
            cell.imageView?.tintColor = .systemGreen
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "item", for: indexPath)
        let deviceProfile: DeviceProfile = {
            if indexPath.section == 0 {
                return DeviceProfile.local
            }
            return profileList[indexPath.row]
        }()
        let textLabelText = deviceProfile.deviceModel + " - " + deviceProfile.deviceBoard
        if let detailedTextLabelText = deviceProfile.ecid {
            cell.textLabel?.text = detailedTextLabelText
            cell.detailTextLabel?.text = textLabelText
        }
        else {
            cell.textLabel?.text = textLabelText
            cell.detailTextLabel?.text = nil
        }

        cell.accessoryType = .none
        if (indexPath.section == 1 && indexPath.row == currentProfileIndex) || (indexPath.section == 0 && currentProfileIndex == nil) {
            cell.accessoryType = .checkmark
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if tableView.isEditing && self.tableView(tableView, canEditRowAt: indexPath) {
            performSegue(withIdentifier: "ToEdit", sender: indexPath)
            return
        }
        // tapping selected local profile
        if indexPath.section == 0 && currentProfileIndex == nil {
            return
        }
        // tapping selected nonlocal profile or "new profile"
        if indexPath.section != 0 {
            if indexPath.row == currentProfileIndex {
                return
            }
            if indexPath.row == profileList.count {
                performSegue(withIdentifier: "ToEdit", sender: nil)
                return
            }
        }
        tableView.visibleCells.first {$0.accessoryType != .none}?.accessoryType = .none
        currentProfileIndex = indexPath.section == 0 ? nil : indexPath.row
        
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
    }
    
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        profileList.swapAt(sourceIndexPath.row, destinationIndexPath.row)
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return indexPath.section == 0 ? .none : .delete
    }
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {

        if editingStyle == .delete {
            profileList.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
        if currentProfileIndex != nil && indexPath.row < currentProfileIndex! {
            // a profile before selected is deleted; recalculate the index
            currentProfileIndex = profileList.firstIndex(of: selectedProfile)
        }
        else if currentProfileIndex == indexPath.row {
            // selected profile is deleted
            if profileList.isEmpty {
                tableView.cellForRow(at: IndexPath(row: 0, section: 0))?.accessoryType = .checkmark
                currentProfileIndex = nil
            }
            else {
                tableView.cellForRow(at: IndexPath(row: indexPath.row, section: 1))?.accessoryType = .checkmark
                currentProfileIndex = indexPath.row
            }
        }
    }
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 0 || indexPath.row != profileList.count
    }
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section != 0 && indexPath.row != profileList.count
    }
    override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        if proposedDestinationIndexPath.section == 0 {
            return IndexPath(row: 0, section: 1)
        }
        if proposedDestinationIndexPath.row == profileList.count {
            return IndexPath(row: profileList.count - 1, section: 1)
        }
        return proposedDestinationIndexPath
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard section == 0 else {
            return nil
        }
        return "Local profile"
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let petvc = segue.destination as? ProfileEditTableViewController {
            let indexPath = sender as? IndexPath
            if let indexPath = indexPath {
                if indexPath.section == 0 {
                    petvc.profile = DeviceProfile.local
                    petvc.isLocalProfile = true
                }
                else {
                    petvc.profile = profileList[indexPath.row]
                }
            }
            petvc.finishEditingProfileBlock = { [unowned self] profile in
                if let indexPath = indexPath {
                    if indexPath.section == 0 {
                        guard DeviceProfile.local.ecid != profile.ecid else { return }
                        DeviceProfile.setlocalECID(profile.ecid)
                        // update ecid via profile
                    }
                    else {
                        guard self.profileList[indexPath.row] != profile else {
                            return
                        }
                        self.profileList[indexPath.row] = profile
                        // no retain cycle since it will be nil out when executed in viewDidAppear
                        self.updateTableViewBlock = {
                            self.tableView.reloadRows(at: [indexPath], with: .automatic)
                        }
                    }
                }
                else {
                    self.profileList.append(profile)
                    self.updateTableViewBlock = {
                        self.tableView.insertRows(at: [IndexPath(row: self.profileList.count - 1, section: 1)], with: .automatic)
                    }
                }
            }
        }
        else if let altvc = segue.destination as? APNonceListTableViewController {
            altvc.currentProfile = selectedProfile
        }
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
extension NSNotification.Name {
    static let DeviceProfileHasChangedNotification = NSNotification.Name(rawValue: "DeviceProfileHasChangedNotification")
}
