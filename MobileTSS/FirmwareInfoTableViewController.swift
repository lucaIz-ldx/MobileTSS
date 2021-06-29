//
//  FirmwareInfoViewController.swift
//  MobileTSS
//
//  Created by User on 7/12/18.
//

import UIKit

class FirmwareInfoTableViewController: UITableViewController {

    var firmwareInfo: CustomFirmwareTableViewController.CustomRequest! {
        didSet {
            displayedInfo = firmwareInfo.visibleInfoDictionary
        }
    }
    var displayedInfo: [(String, String)]!
    let headerViewHeight: CGFloat = 50

    weak var progressOutputVC: ProgressOutputViewController?
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Firmware Info" : nil
    }
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard section == 0, let view = view as? UITableViewHeaderFooterView else {return}
        view.textLabel?.text = "Firmware Info"
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? displayedInfo.count : (firmwareInfo.status.currentStatus == .signed ? 2 : 1)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: {
            let tuple = (indexPath.section, indexPath.row)
            switch tuple {
                case (1, 1):
                    return "button"
                case (1, 0):
                    return "status"
                default:
                    return "info"
            }
        }(), for: indexPath)
        if let cell = cell as? FirmwareInfoTableViewCell {
            firmwareInfoCellConfigure(cell, At: indexPath)
        }
        else if let cell = cell as? StatusLabelTableViewCell {
            statusLabelCellConfigure(cell, At: indexPath)
        }
        else if let cell = cell as? ButtonTableViewCell {
            buttonCellConfigure(cell, At: indexPath)
        }
        return cell
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView(frame: .zero)
    }

    func firmwareInfoCellConfigure(_ cell: FirmwareInfoTableViewCell, At indexPath: IndexPath) {
        // display firmware info
        cell.identifierText = displayedInfo[indexPath.row].0
        cell.contentText = displayedInfo[indexPath.row].1
    }
    func statusLabelCellConfigure(_ cell: StatusLabelTableViewCell, At indexPath: IndexPath) {
        // sign status
        if firmwareInfo.status.currentStatus == .signed {
            cell.contentView.backgroundColor = UIColor.systemGreen
            cell.label.text = "This firmware is being signed. You can save blobs for this version. "
        }
        else {
            cell.contentView.backgroundColor = UIColor.systemRed
            cell.label.text = "This firmware is not being signed. You cannot save blobs for this version. "
        }
    }
    func buttonCellConfigure(_ cell: ButtonTableViewCell, At indexPath: IndexPath) {
        // save shsh.
        cell.button.setTitle("Fetch SHSH Blobs", for: .normal)
        cell.button.setTitleColor(UIColor.gray, for: .highlighted)
        cell.button.removeTarget(nil, action: nil, for: .touchUpInside)
        cell.button.addTarget(self, action: #selector(fetchShshBlobs(WithPressed:)), for: .touchUpInside)
    }
    private typealias BlockWrapper = (() -> Void, () -> Void)

    @objc func fetchShshBlobs(WithPressed button: UIButton) {
        let profile = PreferencesManager.shared.preferredProfile
        guard let ecidString = profile.ecid, let ecid = TSSECID(string: ecidString) else {
            let errorView = UIAlertController(title: LocalizedString.errorTitle, message: "You must provide a valid ECID in preferences before saving shsh blobs.", preferredStyle: .alert)
            errorView.addAction(UIAlertAction(title: "OK", style: .default))
            present(errorView, animated: true)
            return
        }
        let request = TSSRequest(firmwareURL: firmwareInfo.buildManifestURL, deviceBoardConfiguration: profile.deviceBoard, ecid: ecid)
        request.delegate = self
        let apnonceDatabase = NSDictionary(contentsOfFile: GlobalConstants.customAPNonceGenListFilePath) as? [String : [[String : String]]] ?? [:]

        struct CustomNonce {
            var apnonce: TSSAPNonce?
            //                var sepnonce: TSSSEPNonce?
            var generator: TSSGenerator?
        }
        var customAPNonceList = apnonceDatabase[PreferencesManager.shared.preferredProfile.apnonceDatabaseProfileKey]?.compactMap { dict -> CustomNonce? in
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
        }

        if TSSNonce.isNonceEntanglingEnabled(forDeviceModel: profile.deviceModel) {
            // remove trivial entries
            customAPNonceList?.removeAll {
                $0.apnonce == nil || $0.generator == nil
            }
            if customAPNonceList?.isEmpty ?? true {
                let alertView = UIAlertController(title: LocalizedString.errorTitle, message: "A12(X) and above devices need specific nonce and generator pair to save blobs due to nonce entangling. Please add at least one pair in \"Custom APNonce & generator\" in profile.", preferredStyle: .alert)
                alertView.addAction(UIAlertAction(title: "OK", style: .cancel))
                present(alertView, animated: true)
                return
            }
        }
        let destinationDirectory = profile.blobsDirectoryPath!
        performSegue(withIdentifier: "MovingToSaveShsh", sender: ({[weak self] in
            func showAlertWithTitle(_ title: String?, message: String?) {
                guard let `self` = self, self.progressOutputVC?.cancelBlock != nil else {return}
                self.progressOutputVC?.backButtonTitle = "Done"
                let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alertView.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    if #available(iOS 13.0, *) {
                        self.progressOutputVC?.isModalInPresentation = false
                    }
                })
                self.progressOutputVC?.present(alertView, animated: true)
            }
            if var customAPNonceList = customAPNonceList, !customAPNonceList.isEmpty {
                DispatchQueue.global().async {
                    var numOfSuccess = 0
                    let totalOperations = customAPNonceList.count
                    while customAPNonceList.count > 0 {
                        guard let `self` = self else {
                            request.cancel()
                            return
                        }
                        let apgenInfo = customAPNonceList.removeFirst()
                        var string = "Saving blobs for"
                        if let apnonce = apgenInfo.apnonce {
                            string += " apnonce \(apnonce.nonceString)."
                            request.apnonce = apnonce
                        }
                        if let generator = apgenInfo.generator {
                            if string.last == "." {
                                string.removeLast()
                                string.append(";")
                            }
                            string += " generator \(generator.generatorString)."
                            request.generator = generator
                        }
                        string += " (\(totalOperations - customAPNonceList.count)/\(totalOperations))\n"
                        DispatchQueue.main.sync {
                            self.progressOutputVC?.addTextToOutputView(string)
                        }
                        let filePath = try? request.downloadSHSHBlobs(atDirectory: destinationDirectory)
                        if let filePath = filePath {
                            DispatchQueue.main.sync {
                                self.progressOutputVC?.addTextToOutputView("Successfully wrote \((filePath as NSString).lastPathComponent).\n")
                            }
                            numOfSuccess += 1
                        }
                        else {
                            DispatchQueue.main.sync {
                                self.progressOutputVC?.addTextToOutputView("Failed to save blobs.\n")
                            }
                        }
                    }
                    DispatchQueue.main.async {
                        showAlertWithTitle("Result", message: "Successfully saved \(numOfSuccess) shsh blob\(numOfSuccess == 1 ? "" : "s").")
                        NotificationCenter.default.post(name: NSNotification.Name.TSSDocumentsDirectoryContentChanged, object: self)
                    }
                }
            }
            else {
                request.downloadSHSHBlobs(atDirectory: destinationDirectory) { (fileName, error) in
                    if let error = error {
                        DispatchQueue.main.async {
                            showAlertWithTitle(LocalizedString.errorTitle, message: "Failed to fetch SHSH blobs. \(error.localizedDescription)")
                        }
                        return
                    }
                    DispatchQueue.main.async {
                        showAlertWithTitle("Success", message: "SHSH blobs have been saved! Filename: \(fileName!)")
                        NotificationCenter.default.post(name: NSNotification.Name.TSSDocumentsDirectoryContentChanged, object: self)
                    }
                }
            }
            },{request.cancel()}))
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let povc = segue.destination as? ProgressOutputViewController, let block = sender as? BlockWrapper {
            progressOutputVC = povc
            povc.actionAfterViewAppeared = block.0
            povc.cancelBlock = block.1
        }
    }
}
extension FirmwareInfoTableViewController : TSSRequestDelegate {
    func request(_ request: TSSRequest, verboseOutput output: String) {
        DispatchQueue.main.async {
            self.progressOutputVC?.addTextToOutputView(output)
        }
    }
}
