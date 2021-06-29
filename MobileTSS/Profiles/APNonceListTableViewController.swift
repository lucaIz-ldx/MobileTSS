//
//  APNonceTableViewController.swift
//  MobileTSS
//
//  Created by User on 1/27/19.
//

import UIKit

class APNonceListTableViewController: UITableViewController {
    private typealias APNonceDatabase = [String : [[String : String]]]

    var currentProfile: DeviceProfile!
    
    private lazy var databaseKey: String = currentProfile.apnonceDatabaseProfileKey
    private var isModified = false
    private var apnonceDatabase: APNonceDatabase = {
        var database: APNonceDatabase = [:]
        if let dict = NSDictionary(contentsOfFile: GlobalConstants.customAPNonceGenListFilePath) as? APNonceDatabase {
            database = dict
        }
        return database
    }()
    private var apnonceList: [[String : String]] = [] {
        didSet {
            isModified = true
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView()
        NotificationCenter.default.addObserver(self, selector: #selector(saveData), name: UIApplication.willResignActiveNotification, object: UIApplication.shared)

        if let apnonceList = apnonceDatabase[databaseKey] {
            self.apnonceList = apnonceList
            // ignore first set
            isModified = false
        }
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        saveData()
    }
    override func viewDidAppear(_ animated: Bool) {
         super.viewDidAppear(animated)
         guard currentProfile == nil else { return }
         let alert = UIAlertController(title: "Unspecified ECID", message: "ECID is required to save blobs with specific apnonce or generator.", preferredStyle: .alert)
         alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { (_) in
             self.navigationController?.popViewController(animated: true)
         }));
         present(alert, animated: true)
     }
    @objc private func saveData() {
        if isModified {
            if apnonceList.isEmpty {
                apnonceDatabase.removeValue(forKey: databaseKey)
            }
            else {
                apnonceDatabase[databaseKey] = apnonceList
            }
            (apnonceDatabase as NSDictionary).write(toFile: GlobalConstants.customAPNonceGenListFilePath, atomically: true)
            isModified = false
        }
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return apnonceList.count
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "item", for: indexPath)
        let textLabelText = apnonceList[indexPath.row][CustomAPGenKey.APNonce_Key]
        if let detailedTextLabelText = apnonceList[indexPath.row][CustomAPGenKey.Generator_Key] {
            cell.textLabel?.text = detailedTextLabelText
            cell.detailTextLabel?.text = textLabelText
        }
        else {
            cell.textLabel?.text = textLabelText
            cell.detailTextLabel?.text = nil
        }
        return cell
    }
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            apnonceList.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let apetvc = segue.destination as? APNonceEditTableViewController {
            let tableViewCell = sender as? UITableViewCell
            let indexPath = tableViewCell == nil ? nil : tableView.indexPath(for: tableViewCell!)

            apetvc.apgenInfo = indexPath == nil ? [:] : apnonceList[indexPath!.row]
            apetvc.finishEditingCallback = { [unowned self] apgenInfo in
                guard !apgenInfo.isEmpty else {
                    if let indexPath = indexPath {
                        // remove apnonce & generator in existing list
                        self.apnonceList.remove(at: indexPath.row)
                        self.tableView.deleteRows(at: [indexPath], with: .automatic)
                    }
                    return
                }
                if let indexPath = indexPath {
                    let original = self.apnonceList[indexPath.row]
                    if original != apgenInfo {
                        self.apnonceList[indexPath.row] = apgenInfo
                        self.tableView.reloadRows(at: [indexPath], with: .automatic)
                    }
                }
                else {
                    self.apnonceList.append(apgenInfo)
                    self.tableView.insertRows(at: [IndexPath(row: self.apnonceList.count - 1, section: 0)], with: .automatic)
                }
            }
        }
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
extension DeviceProfile {
    static let Local_Key = "Local"
    var apnonceDatabaseProfileKey: String {
        if self == DeviceProfile.local {
            return DeviceProfile.Local_Key
        }
        // when ecid is not set, treat it as default value (they will never be used anyway since saving blobs requires ecid)
        return profileKey
    }
}
