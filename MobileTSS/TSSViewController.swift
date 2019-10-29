//
//  FirstViewController.swift
//  MobileTSS
//
//  Created by User on 7/2/18.
//  Copyright © 2018 User. All rights reserved.
//

import UIKit

class TSSViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    class FirmwareInfo : CustomFirmwareTableViewController.CustomRequest {
        var releaseDate: String?
        init(deviceBoard: String, deviceModel: String, version: String, buildID: String, buildManifestURL: String, status: CustomFirmwareTableViewController.SigningStatus, releaseDate: String?) {
            super.init(deviceBoard: deviceBoard, deviceModel: deviceModel, version: version, buildID: buildID, buildManifestURL: buildManifestURL, isOTA: false, status: CustomFirmwareTableViewController.FetchedTSSResult(currentStatus: status))
            self.releaseDate = releaseDate
        }

        override var visibleInfoDictionary: [(String, String)] {
            guard let releaseDate = releaseDate else { return super.visibleInfoDictionary }
            return super.visibleInfoDictionary + [(JsonKeys.releasedate_Key, releaseDate)]
        }
    }

    @IBOutlet private var tableView: UITableView!

    private weak var loadingEffectBackgroundView: UIView?
    private weak var refreshTask: URLSessionTask?

    private var bottomFootViewInTable: UILabel!
    private var loadedFullFirmwareInfo: [FirmwareInfo]?
    private var allFirmwareInfo : [FirmwareInfo] = []

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.allFirmwareInfo.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "tss", for: indexPath)
        let info = self.allFirmwareInfo[indexPath.row]
        cell.textLabel?.text = info.version + " (\(info.buildID))"
        cell.detailTextLabel?.text = info.status.currentStatus == .Signed ? "You can restore this firmware through iTunes. " : "This firmware is not being signed. "
        // TODO: Image
//        cell.imageView?.image = isSigned ? UIImage.init(named: "Signed") : UIImage.init(named: "notSigned")
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        self.performSegue(withIdentifier: "ToFirmwareInfo", sender: self.allFirmwareInfo[indexPath.row])
    }

    private func applyLoadingView() {
        guard self.loadingEffectBackgroundView == nil else {return}

        let loadingIndicator = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
        let loadingView = UIView()

        loadingView.center = self.view.center
        let distance: CGFloat = 40

        loadingView.frame.size = CGSize(width: loadingIndicator.frame.size.width + distance, height: loadingIndicator.frame.size.height + distance)
        loadingIndicator.center = CGPoint(x: loadingView.frame.size.width/2, y: loadingView.frame.size.height/2)

        loadingView.backgroundColor = UIColor(white: 0, alpha: 0.7)
        loadingView.isOpaque = false
        loadingView.alpha = 0
        loadingView.layer.masksToBounds = true
        loadingView.layer.cornerRadius = 10
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.addSubview(loadingIndicator)

        let centerXConstraint = NSLayoutConstraint(item: loadingView, attribute: .centerX, relatedBy: .equal, toItem: self.view, attribute: .centerX, multiplier: 1, constant: 0)
        let centerYConstraint = NSLayoutConstraint(item: loadingView, attribute: .centerY, relatedBy: .equal, toItem: self.view, attribute: .centerY, multiplier: 1, constant: 0)
        let heightConstraint = NSLayoutConstraint(item: loadingView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: loadingView.frame.size.height)
        let widthConstraint = NSLayoutConstraint(item: loadingView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: loadingView.frame.size.width)

        self.view.addSubview(loadingView)
        NSLayoutConstraint.activate([centerXConstraint, centerYConstraint, heightConstraint, widthConstraint])

        self.loadingEffectBackgroundView = loadingView
        loadingIndicator.startAnimating()
        UIView.animate(withDuration: 0.1) {
            loadingView.alpha = 1
        }
    }
    private func removeLoadingView() {
        guard let loadingView = self.loadingEffectBackgroundView else {return}
        self.loadingEffectBackgroundView = nil
        UIView.animate(withDuration: 0.3, animations: {loadingView.alpha = 0}) { (_) in
            loadingView.removeFromSuperview()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 9.0, *), self.traitCollection.forceTouchCapability == .available {
            registerForPreviewing(with: self, sourceView: self.tableView)
        }
        if #available(iOS 11.0, *) {
            self.tableView.dragDelegate = self
        }
        self.tableView.tableFooterView = UIView(frame: .zero)
        let screenWidth = UIScreen.main.bounds.size.width
        let labelWidth: CGFloat = 220
        self.bottomFootViewInTable = UILabel(frame: CGRect(x: (screenWidth - labelWidth)/2, y: 10, width: labelWidth, height: 30))
        self.bottomFootViewInTable.adjustsFontSizeToFitWidth = true
        self.bottomFootViewInTable.minimumScaleFactor = 12.5/self.bottomFootViewInTable.font.pointSize
        self.bottomFootViewInTable.textColor = UIColor.gray
        self.bottomFootViewInTable.textAlignment = .center
        self.tableView.tableFooterView?.addSubview(self.bottomFootViewInTable)
        self.tableView.contentInset.bottom = 16 + self.bottomFootViewInTable.bounds.size.height
        NotificationCenter.default.addObserver(self, selector: #selector(reloadTable), name: .ShowUnsignedFirmwarePreferenceChanged, object: nil)

        if TSSRequest.localECID == nil {
            let ecidPrompt = UIAlertController(title: "Enter ECID", message: "ECID is not available. Please enter ECID manually below. You can set ECID later in preferences.", preferredStyle: .alert)
            ecidPrompt.addTextField { (textFieldForECID) in
                textFieldForECID.clearButtonMode = .unlessEditing
                textFieldForECID.placeholder = "ECID (Hex/Dec): "
            }
            ecidPrompt.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
                TSSRequest.setECIDToPreferences(nil)
            }))
            ecidPrompt.addAction(UIAlertAction(title: "OK", style: .default, handler: { [unowned ecidPrompt] (_) in
                if (!TSSRequest.setECIDToPreferences((ecidPrompt.textFields?.first?.text)!)) {
                    let errorView = UIAlertController(title: LocalizedString.errorTitle, message: "Failed to parse ECID. Make sure you've entered a valid ECID", preferredStyle: .alert)
                    errorView.addAction(UIAlertAction(title: "OK", style: .default, handler: { (_) in
                        self.tabBarController!.present(ecidPrompt, animated: true)
                    }))
                    self.tabBarController!.present(errorView, animated: true)
                }
            }))
            self.tabBarController!.present(ecidPrompt, animated: true)
        }
        // Do any additional setup after loading the view, typically from a nib.
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.bottomFootViewInTable.center.x = self.view.center.x
    }
    private func refreshData(completionHandler: @escaping (() -> Void)) {
        var request = URLRequest(url: URL(string: "https://api.ipsw.me/v4/device/\(GlobalConstants.localProductType)")!)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
            }
            guard self.loadingEffectBackgroundView != nil else {
                DispatchQueue.main.async(execute: completionHandler)
                return
            }
            if let error = error {
                DispatchQueue.main.async {
                    let alertView = UIAlertController(title: LocalizedString.errorTitle, message: "An error has occurred. \(error.localizedDescription)", preferredStyle: .alert)
                    alertView.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alertView, animated: true)
                    completionHandler()
                }
                return
            }
            if let data = data, let loadedDictionary = (((try? JSONSerialization.jsonObject(with: data)) as? [String : Any])?[JsonKeys.firmwares_Key]) as? [[String : Any]] {
                self.loadedFullFirmwareInfo = loadedDictionary.flatMap { (firmwareDict) -> FirmwareInfo? in
                    guard let version = firmwareDict[JsonKeys.version_Key] as? String,
                        let buildID = firmwareDict[JsonKeys.buildid_Key] as? String,
                        let isSigning = firmwareDict[JsonKeys.signed_Key] as? Bool,
                        let url = firmwareDict[JsonKeys.url_Key] as? String else { return nil }
                    return FirmwareInfo(deviceBoard: GlobalConstants.localDeviceBoard, deviceModel: GlobalConstants.localProductType, version: version, buildID: buildID, buildManifestURL: url, status: isSigning ? .Signed : .Not_Signed, releaseDate: (firmwareDict[JsonKeys.releasedate_Key] as? String)?.components(separatedBy: CharacterSet.uppercaseLetters).first)
                }
                DispatchQueue.main.async {
                    self.reloadTable()
                    completionHandler()
                    self.removeLoadingView()
                }
            }
            else {
                DispatchQueue.main.async {
                    let alertView = UIAlertController(title: LocalizedString.errorTitle, message: "An error has occurred when parsing data from server.", preferredStyle: .alert)
                    alertView.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alertView, animated: true)
                    completionHandler()
                }
            }
        }
        task.resume()
        self.refreshTask = task
    }
    @IBAction private func refreshData(_ sender: UIBarButtonItem) {
        if self.refreshTask == nil {
            self.applyLoadingView()
            self.refreshData {
                self.removeLoadingView()
                sender.title = "Refresh"
            }
            sender.title = "Cancel"
        }
        else {
            self.removeLoadingView()
            self.refreshTask?.cancel()
            sender.title = "Refresh"
        }
    }
    // not used so far
    private func fetchOTAData(deviceModel: String?) -> [[String : Any]]? {
        let otaMetaDataURL = "http://mesu.apple.com/assets/com_apple_MobileAsset_SoftwareUpdate/com_apple_MobileAsset_SoftwareUpdate.xml"
        guard let otaMetaData = NSDictionary.init(contentsOf: URL(string: otaMetaDataURL)!) else {
            print("Failed to get ota data. ")
            return nil
        }
        return otaMetaData.object(forKey: OTAMetaDataKeys.Assets_Key) as? [[String : Any]]
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let firmwarevc = segue.destination as? FirmwareInfoViewController, let sender = sender as? CustomFirmwareTableViewController.CustomRequest {
            firmwarevc.firmwareInfo = sender
        }
    }
    @objc private func reloadTable() {
        guard let loadedFullFirmwareInfo = self.loadedFullFirmwareInfo else {
            return
        }
        if !PreferencesManager.shared.isShowingUnsignedFirmware {
            self.allFirmwareInfo = loadedFullFirmwareInfo.filter {
                return $0.status.currentStatus == .Signed
            }
        }
        else {
            self.allFirmwareInfo = loadedFullFirmwareInfo
        }
        self.bottomFootViewInTable.text = "\(self.allFirmwareInfo.count) Firmware\(self.allFirmwareInfo.count == 1 ? "" : "s")"
        self.tableView.reloadData()
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
@available(iOS 9.0, *)
extension TSSViewController : UIViewControllerPreviewingDelegate {
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        guard let indexPath = self.tableView.indexPathForRow(at: location) else {return nil}
        let firmwareInfoVC = self.storyboard?.instantiateViewController(withIdentifier: "Firmware Info") as! FirmwareInfoViewController
        previewingContext.sourceRect = self.tableView.rectForRow(at: indexPath)
        firmwareInfoVC.firmwareInfo = self.allFirmwareInfo[indexPath.row]
        return firmwareInfoVC
    }

    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        self.show(viewControllerToCommit, sender: nil)
    }
}
@available(iOS 11.0, *)
extension TSSViewController : UITableViewDragDelegate {
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        session.localContext = self.allFirmwareInfo[indexPath.row].buildManifestURL
        return [UIDragItem(itemProvider: NSItemProvider(object: self.allFirmwareInfo[indexPath.row].buildManifestURL as NSItemProviderWriting))]
    }
}
extension NSNotification.Name {
    static let ShowUnsignedFirmwarePreferenceChanged =  NSNotification.Name(rawValue: "ShowUnsignedFirmwarePreferenceChanged")
}
