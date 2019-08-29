//
//  SecondViewController.swift
//  MobileTSS
//
//  Created by User on 7/2/18.
//  Copyright © 2018 User. All rights reserved.
//

import UIKit

class SHSHViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet private var tableView: UITableView!

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
            return (self.path as NSString).lastPathComponent
        }

        var description: String {
            if let deviceModel = self.deviceModel,
                let version = self.version,
                let buildID = self.buildID {
                return "\(deviceModel) - \(version) (\(buildID))\(self.isOTA ? " - OTA" : "") "
            }
            return self.fileName
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
                self.ecid = splittedECID
            }
            if let splittedDeviceModel = optionalGetString(At: 1) {
                self.deviceModel = splittedDeviceModel
            }
            if let splittedVersionBuildID = optionalGetString(At: 2)?.split(separator: "-"), splittedVersionBuildID.count > 1 {
                self.version = String(splittedVersionBuildID[0])
                self.buildID = String(splittedVersionBuildID[1])
                self.isOTA = splittedVersionBuildID.count > 2 && String(splittedVersionBuildID[2]) == "OTA"
            }
            else if let splittedVersionBuildID = optionalGetString(At: 3)?.split(separator: "-"), splittedVersionBuildID.count > 1, let splittedBoard = optionalGetString(At: 2) {
                self.deviceBoard = splittedBoard
                self.version = String(splittedVersionBuildID[0])
                self.buildID = String(splittedVersionBuildID[1])
                self.isOTA = splittedVersionBuildID.count > 2 && String(splittedVersionBuildID[2]) == "OTA"
            }
            if splittedArray.count >= 4, let apNonce = splittedArray.last {
                self.apnonce = String(apNonce)
            }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.shshSavedInLocal.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "shsh", for: indexPath)
        cell.detailTextLabel?.text = self.shshSavedInLocal[indexPath.row].apnonce
        cell.textLabel?.text = self.shshSavedInLocal[indexPath.row].description
        return cell
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(refreshLocalDocuments(_:)), name: NSNotification.Name.TSSDocumentsDirectoryContentChanged, object: nil)

        self.tableView.tableFooterView = UIView(frame: .zero)
        let screenWidth = UIScreen.main.bounds.size.width
        let labelWidth: CGFloat = 220
        self.bottomFooterLabelInTable = UILabel(frame: CGRect(x: (screenWidth - labelWidth)/2, y: 10, width: labelWidth, height: 30))
        self.bottomFooterLabelInTable.adjustsFontSizeToFitWidth = true
        self.bottomFooterLabelInTable.minimumScaleFactor = 12.5/self.bottomFooterLabelInTable.font.pointSize
        self.bottomFooterLabelInTable.textColor = UIColor.gray
        self.bottomFooterLabelInTable.textAlignment = .center
        self.tableView.tableFooterView?.addSubview(self.bottomFooterLabelInTable)
        self.tableView.contentInset.bottom = 16 + self.bottomFooterLabelInTable.bounds.size.height

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshLocalDocuments(_:)), for: .valueChanged)
        self.tableView.addSubview(refreshControl)
        self.refreshLocalDocuments(nil)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let selectedIndexPath = self.tableView.indexPathForSelectedRow {
            self.tableView.deselectRow(at: selectedIndexPath, animated: true)
        }
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.bottomFooterLabelInTable.center.x = self.view.center.x
    }
    private func updateLabelAtBottom() {
        self.bottomFooterLabelInTable.text = self.shshSavedInLocal.isEmpty ? "" : "\(self.shshSavedInLocal.count) item\(self.shshSavedInLocal.count == 1 ? "" : "s")"
    }

    @objc private func refreshLocalDocuments(_ sender: Any?) {
        do {
            self.shshSavedInLocal = try FileManager.default.contentsOfDirectory(atPath: GlobalConstants.documentsDirectoryPath).flatMap { (fileName) -> SHSHInfo? in
                    guard (fileName as NSString).pathExtension.starts(with: "shsh") else {return nil}
                    return SHSHInfo(contentsOfFile: GlobalConstants.documentsDirectoryPath + fileName)
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
            self.tableView.reloadData()
        } catch let error {
            let alertController = UIAlertController(title: LocalizedString.errorTitle, message: "An error has occurred when retrieve a list of local documents directory. \(error.localizedDescription)", preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .cancel))
            self.present(alertController, animated: true)
        }
        self.updateLabelAtBottom()
        (sender as? UIRefreshControl)?.endRefreshing()
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let shshdvc = segue.destination as? SHSHDetailsViewController, let sender = sender as? UITableViewCell {
            let indexPath: IndexPath = self.tableView.indexPath(for: sender)!
            shshdvc.shshInfo = self.shshSavedInLocal[indexPath.row]
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
    static let TSSDocumentsDirectoryContentChanged =  NSNotification.Name(rawValue: "TSSDocumentsDirectoryContentChanged")
}
