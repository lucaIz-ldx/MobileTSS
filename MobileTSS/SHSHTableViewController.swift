//
//  SecondViewController.swift
//  MobileTSS
//
//  Created by User on 7/2/18.
//  Copyright © 2018 User. All rights reserved.
//

import UIKit

class SHSHTableViewController: UITableViewController {

    private var bottomFooterLabelInTable: UILabel!
    private var shshSavedInLocal : [SHSHInfo] = []

    struct SHSHInfo {
        var ecid: String?
        var deviceModel: String?
        var deviceBoard: String?
        var version: String?
        var buildID: String?
        var apnonce: String?
        var isOTA: Bool = false
        let path: String
        var fileName: String {
            return (path as NSString).lastPathComponent
        }

        var description: String {
            if let deviceModel = deviceModel,
                let version = version,
                let buildID = buildID {
                return "\(deviceModel) - \(version) (\(buildID))\(isOTA ? " - OTA" : "") "
            }
            return fileName
        }

        //        deviceBoard: String?, deviceModel: String?, version: String?, buildID: String?, apnonce: String?
        init(contentsOfFile path: String) {
            self.path = path
            let splittedArray = ((path as NSString).lastPathComponent as NSString).deletingPathExtension.split(separator: "_")
            func optionalGetString(At index: Int) -> String? {
                if index >= splittedArray.count {
                    return nil
                }
                return String(splittedArray[index])
            }
            // Filename: ECID_Model_Board_Version-BuildID-OTA_apnonce.shsh2
            //             0   1       2          3             4
            if let splittedECID = optionalGetString(At: 0) {
                ecid = splittedECID
            }
            if let splittedDeviceModel = optionalGetString(At: 1) {
                deviceModel = splittedDeviceModel
            }
            if let splittedVersionBuildID = optionalGetString(At: 2)?.split(separator: "-"), splittedVersionBuildID.count > 1 {
                version = String(splittedVersionBuildID[0])
                buildID = String(splittedVersionBuildID[1])
                isOTA = splittedVersionBuildID.count > 2 && String(splittedVersionBuildID[2]) == "OTA"
            }
            else if let splittedVersionBuildID = optionalGetString(At: 3)?.split(separator: "-"), splittedVersionBuildID.count > 1, let splittedBoard = optionalGetString(At: 2) {
                deviceBoard = splittedBoard
                version = String(splittedVersionBuildID[0])
                buildID = String(splittedVersionBuildID[1])
                isOTA = splittedVersionBuildID.count > 2 && String(splittedVersionBuildID[2]) == "OTA"
            }
            if splittedArray.count >= 4, let apNonce = splittedArray.last {
                apnonce = String(apNonce)
            }
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return shshSavedInLocal.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "shsh", for: indexPath)
        cell.detailTextLabel?.text = shshSavedInLocal[indexPath.row].apnonce
        cell.textLabel?.text = shshSavedInLocal[indexPath.row].description
        return cell
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(refreshLocalDocuments(_:)), name: NSNotification.Name.TSSDocumentsDirectoryContentChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshLocalDocuments(_:)), name: NSNotification.Name.DeviceProfileHasChangedNotification, object: nil)

        tableView.tableFooterView = UIView(frame: .zero)
        let screenWidth = UIScreen.main.bounds.size.width
        let labelWidth: CGFloat = 220
        bottomFooterLabelInTable = UILabel(frame: CGRect(x: (screenWidth - labelWidth)/2, y: 10, width: labelWidth, height: 30))
        bottomFooterLabelInTable.adjustsFontSizeToFitWidth = true
        bottomFooterLabelInTable.minimumScaleFactor = 12.5/bottomFooterLabelInTable.font.pointSize
        bottomFooterLabelInTable.textColor = UIColor.gray
        bottomFooterLabelInTable.textAlignment = .center
        tableView.tableFooterView?.addSubview(bottomFooterLabelInTable)
        tableView.contentInset.bottom = 16 + bottomFooterLabelInTable.bounds.size.height

        refreshLocalDocuments(nil)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let selectedIndexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selectedIndexPath, animated: true)
        }
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        bottomFooterLabelInTable.center.x = view.center.x
    }
    private func updateLabelAtBottom() {
        bottomFooterLabelInTable.text = shshSavedInLocal.isEmpty ? "" : "\(shshSavedInLocal.count) item\(shshSavedInLocal.count == 1 ? "" : "s")"
    }

    @IBAction private func refreshLocalDocuments(_ sender: Any?) {
        do {
            if let directoryPath = PreferencesManager.shared.preferredProfile.blobsDirectoryPath {
                shshSavedInLocal = try FileManager.default.contentsOfDirectory(atPath: directoryPath).compactMap {
                    guard ($0 as NSString).pathExtension.starts(with: "shsh") else {return nil}
                    return SHSHInfo(contentsOfFile: directoryPath + "/\($0)")
                }.sorted { (info1, info2) -> Bool in
                    let firstVer = (info1.version?.split(separator: ".")) ?? []
                    let secondVer = (info2.version?.split(separator: ".")) ?? []
                    let shorterVer = min(firstVer.count, secondVer.count)
                    for index in 0..<shorterVer {
                        let (firstNum, secondNum): (Int, Int) = (Int(firstVer[index])!, Int(secondVer[index])!)
                        if firstNum == secondNum {
                            continue
                        }
                        return firstNum > secondNum
                    }
                    return firstVer.count > secondVer.count
                }
            }
            else {
                shshSavedInLocal = []
            }
            tableView.reloadData()
        } catch let error {
            let alertController = UIAlertController(title: LocalizedString.errorTitle, message: "An error has occurred when retrieve a list of local documents directory. \(error.localizedDescription)", preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .cancel))
            present(alertController, animated: true)
        }
        updateLabelAtBottom()
        (sender as? UIRefreshControl)?.endRefreshing()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let shshdvc = segue.destination as? SHSHDetailsViewController, let sender = sender as? UITableViewCell {
            let indexPath: IndexPath = tableView.indexPath(for: sender)!
            shshdvc.shshInfo = shshSavedInLocal[indexPath.row]
            shshdvc.deleteSHSHAndUpdateTableViewCallback = {
                self.shshSavedInLocal.remove(at: indexPath.row)
                self.tableView.deleteRows(at: [indexPath], with: .automatic)
                self.updateLabelAtBottom()
            }
        }
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
extension NSNotification.Name {
    static let TSSDocumentsDirectoryContentChanged = NSNotification.Name(rawValue: "TSSDocumentsDirectoryContentChanged")
}
extension DeviceProfile {
    var blobsDirectoryPath: String? {
        if DeviceProfile.local == self {
            return GlobalConstants.documentsDirectoryPath
        }
        if ecid == nil {
            return nil
        }
        let path = GlobalConstants.documentsDirectoryPath + apnonceDatabaseProfileKey
        try! FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }
}
