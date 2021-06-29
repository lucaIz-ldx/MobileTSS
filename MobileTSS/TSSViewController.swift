//
//  FirstViewController.swift
//  MobileTSS
//
//  Created by User on 7/2/18.
//  Copyright © 2018 User. All rights reserved.
//

import UIKit

class TSSViewController: UITableViewController {
    class FirmwareInfo : CustomFirmwareTableViewController.CustomRequest {
        var releaseDate: String?
        init(deviceBoard: String, deviceModel: String, version: String, buildID: String, buildManifestURL: String, status: CustomFirmwareTableViewController.SigningStatus, releaseDate: String?) {
            super.init(deviceBoard: deviceBoard, deviceModel: deviceModel, version: version, buildID: buildID, buildManifestURL: buildManifestURL, isOTA: false, status: CustomFirmwareTableViewController.FetchedTSSResult(currentStatus: status))
            self.releaseDate = releaseDate
        }

        override var visibleInfoDictionary: [(String, String)] {
            guard let releaseDate = releaseDate else { return super.visibleInfoDictionary }
            return super.visibleInfoDictionary + [(LocalizedString.releasedate, releaseDate)]
        }
    }

    private weak var loadingEffectBackgroundView: UIView?
    private weak var refreshTask: URLSessionTask?

    private var bottomFootViewInTable: UILabel!
    private var allFirmwareInfo: [FirmwareInfo]?
    private var displayedFirmwareInfo : [FirmwareInfo] = []

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayedFirmwareInfo.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "tss", for: indexPath)
        let info = displayedFirmwareInfo[indexPath.row]
        cell.textLabel?.text = info.version + " (\(info.buildID))"
        cell.detailTextLabel?.text = info.status.currentStatus == .signed ? "You can restore this firmware through iTunes. " : "This firmware is not being signed. "
        // TODO: Image
//        cell.imageView?.image = info.status.currentStatus == .signed ? TSSViewController.greenCheckMarkImage : TSSViewController.redCrossImage
        return cell
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dragDelegate = self
        tableView.tableFooterView = UIView(frame: .zero)
        let screenWidth = UIScreen.main.bounds.size.width
        let labelWidth: CGFloat = 220
        bottomFootViewInTable = UILabel(frame: CGRect(x: (screenWidth - labelWidth)/2, y: 10, width: labelWidth, height: 30))
        bottomFootViewInTable.adjustsFontSizeToFitWidth = true
        bottomFootViewInTable.minimumScaleFactor = 12.5/bottomFootViewInTable.font.pointSize
        bottomFootViewInTable.textColor = UIColor.gray
        bottomFootViewInTable.textAlignment = .center
        tableView.tableFooterView?.addSubview(bottomFootViewInTable)
        tableView.contentInset.bottom = 16 + bottomFootViewInTable.bounds.size.height
        NotificationCenter.default.addObserver(self, selector: #selector(reloadTable), name: .ShowUnsignedFirmwarePreferenceChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(deviceProfileHasChanged), name: .DeviceProfileHasChangedNotification, object: nil)
        // Do any additional setup after loading the view, typically from a nib.
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        bottomFootViewInTable.center.x = view.center.x
    }
    private func downloadDataFromRemote(completionHandler: @escaping (() -> Void)) {
        let profile = PreferencesManager.shared.preferredProfile
        var request = URLRequest(url: URL(string: "https://api.ipsw.me/v4/device/\(profile.deviceModel)")!)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
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
                self.allFirmwareInfo = loadedDictionary.compactMap { (firmwareDict) -> FirmwareInfo? in
                    guard let version = firmwareDict[JsonKeys.version_Key] as? String,
                        let buildID = firmwareDict[JsonKeys.buildid_Key] as? String,
                        let isSigning = firmwareDict[JsonKeys.signed_Key] as? Bool,
                        let url = firmwareDict[JsonKeys.url_Key] as? String else { return nil }
                    return FirmwareInfo(deviceBoard: profile.deviceBoard, deviceModel: profile.deviceModel, version: version, buildID: buildID, buildManifestURL: url, status: isSigning ? .signed : .notSigned, releaseDate: (firmwareDict[JsonKeys.releasedate_Key] as? String)?.components(separatedBy: CharacterSet.uppercaseLetters).first)
                }
                DispatchQueue.main.async {
                    self.reloadTable()
                    completionHandler()
                    self.removeLoadingView(self.loadingEffectBackgroundView)
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
        refreshTask = task
    }
    @IBAction private func refreshButtonTapped() {
        guard refreshTask == nil else { return }
        loadingEffectBackgroundView = applyLoadingView()
        downloadDataFromRemote(completionHandler: cancelButtonTapped)
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(cancelButtonTapped))
    }
    @objc private func cancelButtonTapped() {
        removeLoadingView(loadingEffectBackgroundView)
        refreshTask?.cancel()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(refreshButtonTapped))
    }
    // not used so far
//    private func fetchOTAData(deviceModel: String?) -> [[String : Any]]? {
//        let otaMetaDataURL = "http://mesu.apple.com/assets/com_apple_MobileAsset_SoftwareUpdate/com_apple_MobileAsset_SoftwareUpdate.xml"
//        guard let otaMetaData = NSDictionary.init(contentsOf: URL(string: otaMetaDataURL)!) else {
//            print("Failed to get ota data. ")
//            return nil
//        }
//        return otaMetaData.object(forKey: OTAMetaDataKeys.Assets_Key) as? [[String : Any]]
//    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let firmwarevc = segue.destination as? FirmwareInfoTableViewController, let sender = sender as? UITableViewCell {
            firmwarevc.firmwareInfo = displayedFirmwareInfo[tableView.indexPath(for: sender)!.row]
        }
    }
    @objc private func reloadTable() {
        guard let loadedFullFirmwareInfo = allFirmwareInfo else {
            return
        }
        if !PreferencesManager.shared.isShowingUnsignedFirmware {
            displayedFirmwareInfo = loadedFullFirmwareInfo.filter {
                return $0.status.currentStatus == .signed
            }
        }
        else {
            displayedFirmwareInfo = loadedFullFirmwareInfo
        }
        bottomFootViewInTable.text = "\(displayedFirmwareInfo.count) Firmware\(displayedFirmwareInfo.count == 1 ? "" : "s")"
        tableView.reloadData()
    }
    @objc private func deviceProfileHasChanged() {
        bottomFootViewInTable.text = nil
        allFirmwareInfo = nil
        displayedFirmwareInfo = []
        tableView.reloadData()
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
extension TSSViewController : UITableViewDragDelegate {
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        session.localContext = displayedFirmwareInfo[indexPath.row].buildManifestURL
        return [UIDragItem(itemProvider: NSItemProvider(object: displayedFirmwareInfo[indexPath.row].buildManifestURL as NSItemProviderWriting))]
    }
}
extension NSNotification.Name {
    static let ShowUnsignedFirmwarePreferenceChanged =  NSNotification.Name(rawValue: "ShowUnsignedFirmwarePreferenceChanged")
}
// load view utilities
extension UIViewController {
    func applyLoadingView() -> UIView {
//        guard loadingEffectBackgroundView == nil else {return}

        let loadingIndicator = UIActivityIndicatorView(style: .whiteLarge)
        let loadingView = UIView()

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

        view.addSubview(loadingView)
        let parentView: UIView = {
            if let nav = navigationController?.view {
                return nav
            }
            if let tab = tabBarController?.view {
                return tab
            }
            return view
        }()
        loadingView.centerXAnchor.constraint(equalTo: parentView.centerXAnchor, constant: 0).isActive = true
        loadingView.centerYAnchor.constraint(equalTo: parentView.centerYAnchor, constant: 0).isActive = true
        loadingView.heightAnchor.constraint(equalToConstant: loadingView.bounds.size.height).isActive = true
        loadingView.widthAnchor.constraint(equalToConstant: loadingView.bounds.size.width).isActive = true

//        loadingEffectBackgroundView = loadingView
        loadingIndicator.startAnimating()
        UIView.animate(withDuration: 0.1) {
            loadingView.alpha = 1
        }
        return loadingView
    }
    func removeLoadingView(_ loadingView: UIView?) {
        guard let loadingView = loadingView else {return}
        UIView.animate(withDuration: 0.3, animations: {loadingView.alpha = 0}) { (_) in
            loadingView.removeFromSuperview()
        }
    }
}
