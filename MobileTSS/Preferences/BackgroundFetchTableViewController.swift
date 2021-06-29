//
//  BackgroundFetchTableViewController.swift
//  MobileTSS
//
//  Created by Luca on 6/6/21.
//

import UIKit

class BackgroundFetchTableViewController: UITableViewController {

    @IBOutlet private weak var backgroundFetchSwitch: UISwitch!
    @IBOutlet private weak var fetchblobsSwitch: UISwitch!
    @IBOutlet private weak var monitorSigningStatusSwitch: UISwitch!
    @IBOutlet private weak var verboseNotificationSwitch: UISwitch!
    
    private var isFetchIntervalSelected: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(reloadSettings(_:)), name: UIApplication.backgroundRefreshStatusDidChangeNotification, object: UIApplication.shared)
        reloadSettings(nil)
    }
    
    // MARK: - Actions
    @objc private func reloadSettings(_ notification: Notification?) {
        if UIApplication.shared.backgroundRefreshStatus != .available {
            backgroundFetchSwitch.isOn = false
            PreferencesManager.shared.isBackgroundFetchingOn = false
            backgroundFetchSwitch.isEnabled = false
        }
        else {
            backgroundFetchSwitch.isEnabled = true
            backgroundFetchSwitch.isOn = PreferencesManager.shared.isBackgroundFetchingOn
            fetchblobsSwitch.isOn = PreferencesManager.shared.fetchSHSHBlobsBackground
            monitorSigningStatusSwitch.isOn = PreferencesManager.shared.monitorSigningStatus
            verboseNotificationSwitch.isOn = PreferencesManager.shared.verboseNotification
        }
        if notification != nil {
            tableView.reloadData()
        }
    }
    @IBAction private func backgroundFetchSwitchValueChanged(_ sender: UISwitch) {
        PreferencesManager.shared.isBackgroundFetchingOn = sender.isOn
        let reloadSectionIndexSet: IndexSet = [1,2,3]
        if sender.isOn {
            tableView.insertSections(reloadSectionIndexSet, with: .fade)
        }
        else {
            tableView.deleteSections(reloadSectionIndexSet, with: .fade)
            isFetchIntervalSelected = false
        }
    }
    @IBAction private func fetchBlobsSwitchValueChanged(_ sender: UISwitch) {
        PreferencesManager.shared.fetchSHSHBlobsBackground = sender.isOn
        let reloadIndexPathArray = [IndexPath(row: 1, section: 1)]
        if sender.isOn {
            tableView.insertRows(at: reloadIndexPathArray, with: .fade)
        }
        else {
            tableView.deleteRows(at: reloadIndexPathArray, with: .fade)
        }
    }
    @IBAction private func verboseNotificationValueChanged(_ sender: UISwitch) {
        PreferencesManager.shared.verboseNotification = sender.isOn
    }
    @IBAction private func monitorSSSwitchValueChanged(_ sender: UISwitch) {
        PreferencesManager.shared.monitorSigningStatus = sender.isOn
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        if backgroundFetchSwitch.isOn == false {
            return 1
        }
        return super.numberOfSections(in: tableView)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 1 {
            // TODO: add "profiles" here to allow user to select profile
            return fetchblobsSwitch.isOn ? 2 : 1
        }
        if section == 3 {
            return isFetchIntervalSelected ? 2 : 1
        }
        return super.tableView(tableView, numberOfRowsInSection: section)
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        guard indexPath.section == 3 else {
            return cell
        }
        if indexPath.row == 0 {
            cell.detailTextLabel?.text = BackgroundFetchTableViewController.cases[PreferencesManager.shared.fetchIntervalAtIndex]
        }
        else if indexPath.row == 1 {
            let view = cell.contentView.subviews.first {$0 is UIPickerView} as! UIPickerView
            view.selectRow(PreferencesManager.shared.fetchIntervalAtIndex, inComponent: 0, animated: false)
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 3 && indexPath.row == 0 else {
            return
        }
        guard isFetchIntervalSelected == false else {
            return
        }
        isFetchIntervalSelected = true
        tableView.insertRows(at: [IndexPath(row: 1, section: 3)], with: .fade)
    }

}
extension BackgroundFetchTableViewController : UIPickerViewDataSource, UIPickerViewDelegate {
    static let cases = PreferencesManager.FetchInterval.allCases.map {$0.description}
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return BackgroundFetchTableViewController.cases.count
    }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return BackgroundFetchTableViewController.cases[row]
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        PreferencesManager.shared.fetchIntervalAtIndex = row
        tableView.cellForRow(at: IndexPath(row: 0, section: 3))?.detailTextLabel?.text = BackgroundFetchTableViewController.cases[PreferencesManager.shared.fetchIntervalAtIndex]
    }
}
