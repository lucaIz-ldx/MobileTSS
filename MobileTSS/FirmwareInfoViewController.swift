//
//  FirmwareInfoViewController.swift
//  MobileTSS
//
//  Created by User on 7/12/18.
//

import UIKit

class FirmwareInfoViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var firmwareInfo: CustomFirmwareTableViewController.CustomRequest! {
        didSet {
            self.displayedInfo = firmwareInfo.visibleInfoDictionary
        }
    }
    var displayedInfo: [(String, String)]!
    let headerViewHeight: CGFloat = 50

    weak var progressOutputVC: ProgressOutputViewController?
    
    @IBOutlet var tableView: UITableView!

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Firmware Info" : nil
    }
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard section == 0, let view = view as? UITableViewHeaderFooterView else {return}
        view.textLabel?.text = "Firmware Info"
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? self.displayedInfo.count : (self.firmwareInfo.status.currentStatus == .Signed ? 2 : 1)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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
            self.firmwareInfoCellConfigure(cell, At: indexPath)
        }
        else if let cell = cell as? StatusLabelTableViewCell {
            self.statusLabelCellConfigure(cell, At: indexPath)
        }
        else if let cell = cell as? ButtonTableViewCell {
            self.buttonCellConfigure(cell, At: indexPath)
        }
        return cell
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.tableFooterView = UIView(frame: .zero)
    }

    func firmwareInfoCellConfigure(_ cell: FirmwareInfoTableViewCell, At indexPath: IndexPath) {
        // display firmware info
        cell.identifierText = self.displayedInfo[indexPath.row].0
        cell.contentText = self.displayedInfo[indexPath.row].1
    }
    func statusLabelCellConfigure(_ cell: StatusLabelTableViewCell, At indexPath: IndexPath) {
        // sign status
        if self.firmwareInfo.status.currentStatus == .Signed {
            cell.backgroundColor = UIColor.green
            cell.label.text = "This firmware is being signed. You can save blobs for this version. "
        }
        else {
            cell.backgroundColor = UIColor.red
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

    @objc func fetchShshBlobs(WithPressed button: UIButton) {
        if let localECID = TSSRequest.localECID, localECID.isEmpty == false {
            let request = TSSRequest(firmwareURL: self.firmwareInfo.buildManifestURL, deviceBoardConfiguration: GlobalConstants.localDeviceBoard, ecid: localECID)
            request.delegate = self
            request.timeout = 7
            let customAPNonceList = NSArray(contentsOfFile: GlobalConstants.customAPNonceGenListFilePath) as? [[String : String]]

            if isCurrentDeviceNonceEntanglingEnabled() && customAPNonceList?.first(where: {$0[CustomAPGenKey.APNonce_Key] != nil && $0[CustomAPGenKey.Generator_Key] != nil}) == nil {
                let alertView = UIAlertController(title: "Error", message: "A12(X) and above devices need specific nonce and generator pair to save blobs due to nonce entangling. Please add at least one pair in preferences.", preferredStyle: .alert)
                alertView.addAction(UIAlertAction(title: "OK", style: .cancel))
                self.present(alertView, animated: true)
                return
            }
            self.performSegue(withIdentifier: "MovingToSaveShsh", sender: ({[weak self] in
                func showAlertWithTitle(_ title: String?, message: String?) {
                    guard let `self` = self, self.progressOutputVC?.cancelBlock != nil else {return}
                    self.progressOutputVC?.backButtonTitle = "Done"
                    let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)
                    alertView.addAction(UIAlertAction(title: "OK", style: .default))
                    self.progressOutputVC?.present(alertView, animated: true)
                }
                if var customAPNonceList = customAPNonceList, !customAPNonceList.isEmpty {
                    if isCurrentDeviceNonceEntanglingEnabled() {
                       customAPNonceList = customAPNonceList.filter {$0[CustomAPGenKey.APNonce_Key] != nil && $0[CustomAPGenKey.Generator_Key] != nil}
                    }
                    DispatchQueue.global().async {
                        var numOfSuccess = 0
                        while customAPNonceList.count > 0 {
                            guard let `self` = self else {
                                request.cancelGlobalConnection()
                                return
                            }
                            let apgenInfo = customAPNonceList.removeFirst()
                            var string = "Saving blobs for"
                            if let apnonce = apgenInfo[CustomAPGenKey.APNonce_Key] {
                                string += " apnonce \(apnonce)"
                                request.apnonce = apnonce
                            }
                            if let generator = apgenInfo[CustomAPGenKey.Generator_Key] {
                                string += " generator \(generator).\n"
                                request.generator = generator
                            }
                            DispatchQueue.main.sync {
                                self.progressOutputVC?.addTextToOutputView(string)
                            }
                            let filePath = try? request.fetchSHSHBlobs()
                            if let filePath = filePath {
                                DispatchQueue.main.sync {
                                    self.progressOutputVC?.addTextToOutputView("Successfully wrote \((filePath as NSString).lastPathComponent).")
                                }
                                numOfSuccess += 1
                            }
                        }
                        DispatchQueue.main.async {
                            showAlertWithTitle("Result", message: "Saved \(numOfSuccess) shsh blob\(numOfSuccess == 1 ? "" : "s").")
                            NotificationCenter.default.post(name: NSNotification.Name.TSSDocumentsDirectoryContentChanged, object: self)
                        }
                    }
                }
                else {
                    DispatchQueue.global().async {
                        do {
                            let filePath = try request.fetchSHSHBlobs()
                            DispatchQueue.main.async {
                                showAlertWithTitle("Success", message: "SHSH blobs have been saved! Filename: \((filePath as NSString).lastPathComponent)")
                                NotificationCenter.default.post(name: NSNotification.Name.TSSDocumentsDirectoryContentChanged, object: self)
                            }
                        } catch let error {
                            DispatchQueue.main.async {
                                showAlertWithTitle(LocalizedString.errorTitle, message: "Failed to fetch SHSH blobs. \(error.localizedDescription)")
                            }
                        }
                    }
                }
                },{request.cancelGlobalConnection()}))
        }
        else {
            let errorView = UIAlertController(title: LocalizedString.errorTitle, message: "You must provide a valid ECID in preferences before saving shsh blobs.", preferredStyle: .alert)
            errorView.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(errorView, animated: true)
        }
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let povc = segue.destination as? ProgressOutputViewController, let block = sender as? (() -> Void, () -> Void) {
            self.progressOutputVC = povc
            povc.actionAfterViewAppeared = block.0
            povc.cancelBlock = block.1
        }
    }
}
extension FirmwareInfoViewController : TSSRequestDelegate {
    func request(_ request: TSSRequest, sendMessageOutput output: String) {
        DispatchQueue.main.async {
            self.progressOutputVC?.addTextToOutputView(output)
        }
    }
}
