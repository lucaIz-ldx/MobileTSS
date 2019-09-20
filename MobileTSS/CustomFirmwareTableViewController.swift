//
//  CustomFirmwareTableViewController.swift
//  MobileTSS
//
//  Created by User on 7/24/18.
//

import UIKit

class CustomFirmwareTableViewController: UITableViewController {
    enum SigningStatus {
        case Signed
        case Not_Signed
        case Unknown    // default, when a new request is created.
        case Error  // an error has occurred
    }
    class CustomRequest {
        struct ArchivableKeys {
             static let Version_Key = JsonKeys.version_Key
             static let BuildID_Key = JsonKeys.buildid_Key
             static let DeviceModel_Key = JsonKeys.identifier_Key
             static let DeviceBoard_Key = "DeviceBoard"
             static let BuildManifestURL_Key = JsonKeys.url_Key
             static let isOTAVersion_Key = "isOTAVersion"
             static let Label_Key = "Label"
        }
        struct NonArchivableKeys {
             static let signingStatus_Key = JsonKeys.signed_Key
             static let LastRefreshedDate_Key = "Last Refreshed"
             static let errorMessage_Key = "Error Message"
        }
        let deviceModel: String
        let deviceBoard: String
        let version: String
        let buildID: String
        let buildManifestURL: String
        let isOTA: Bool
        var label: String?
        fileprivate(set) var status: FetchedTSSResult

        var visibleInfoDictionary: [(String, String)] {
            return Array(zip([JsonKeys.identifier_Key, "Board", JsonKeys.version_Key, JsonKeys.buildid_Key], [self.deviceModel, self.deviceBoard, self.version, self.buildID]))
        }

        fileprivate var archivableDictionary: [String : Any] {
            var dict = [CustomRequest.ArchivableKeys.BuildManifestURL_Key: self.buildManifestURL,
                        CustomRequest.ArchivableKeys.BuildID_Key: self.buildID,
                        CustomRequest.ArchivableKeys.Version_Key: self.version,
                        CustomRequest.ArchivableKeys.isOTAVersion_Key: self.isOTA,
                        CustomRequest.ArchivableKeys.DeviceModel_Key: self.deviceModel,
                        CustomRequest.ArchivableKeys.DeviceBoard_Key: self.deviceBoard] as [String : Any]
            if let label = self.label {
                dict[CustomRequest.ArchivableKeys.Label_Key] = label
            }
            return dict
        }
        fileprivate var description: String {
            return self.label ?? "\(self.deviceModel) - \(self.version) (\(self.buildID))\(self.isOTA ? " - OTA" : "")"
        }

        init(deviceBoard: String, deviceModel: String, version: String, buildID: String, buildManifestURL: String, isOTA: Bool, status: FetchedTSSResult? = nil) {
            self.deviceBoard = deviceBoard
            self.deviceModel = deviceModel
            self.version = version
            self.buildID = buildID
            self.isOTA = isOTA
            self.buildManifestURL = buildManifestURL
            self.status = status ?? FetchedTSSResult(currentStatus: .Unknown)
        }

        fileprivate init?(_ archivedDictionary: [String : Any]) {
            guard let deviceModel = archivedDictionary[CustomRequest.ArchivableKeys.DeviceModel_Key] as? String,
                let version = archivedDictionary[CustomRequest.ArchivableKeys.Version_Key] as? String,
                let buildID = archivedDictionary[CustomRequest.ArchivableKeys.BuildID_Key] as? String,
                let buildManifestURL = archivedDictionary[CustomRequest.ArchivableKeys.BuildManifestURL_Key] as? String, { () -> Bool in
                    if let buildManifestURL = URL(string: buildManifestURL) {
                        return UIApplication.shared.canOpenURL(buildManifestURL)
                    }
                    return false
                }() else { return nil }
            if let deviceBoard = archivedDictionary[CustomRequest.ArchivableKeys.DeviceBoard_Key] as? String {
                self.deviceBoard = deviceBoard
            }
            else if let foundBoard = findDeviceInfoForSpecifiedModel(deviceModel)?.pointee.deviceBoardConfiguration {
                // !!!: might cause board mismatch problem.
                self.deviceBoard = String(cString: foundBoard)
            }
            else {
                return nil
            }
            self.deviceModel = deviceModel
            self.version = version
            self.buildID = buildID
            self.buildManifestURL = buildManifestURL
            self.isOTA = archivedDictionary[CustomRequest.ArchivableKeys.isOTAVersion_Key] as? Bool ?? false
            self.label = archivedDictionary[CustomRequest.ArchivableKeys.Label_Key] as? String
            self.status = FetchedTSSResult(currentStatus: .Unknown)
        }
    }

    struct FetchedTSSResult : Equatable {
        let currentStatus: SigningStatus
        let lastRefreshedDate: Date?
        let localizedErrorMessage: String?
        init(currentStatus: SigningStatus) {
            self.init(currentStatus: currentStatus, lastRefreshedDate: nil, localizedErrorMessage: nil)
        }
        fileprivate init(currentStatus: SigningStatus, lastRefreshedDate: Date?, localizedErrorMessage: String?) {
            self.currentStatus = currentStatus
            self.lastRefreshedDate = lastRefreshedDate
            self.localizedErrorMessage = localizedErrorMessage
        }
        static func ==(_ firstResult: FetchedTSSResult, _ anotherFetchedTSSResult: FetchedTSSResult) -> Bool {
            return firstResult.currentStatus == anotherFetchedTSSResult.currentStatus
        }
        static func firmwareSigningStatusConverter(_ status: TSSFirmwareSigningStatus) -> SigningStatus {
            switch status {
            case .notSigned:
                return .Not_Signed
            case .signed:
                return .Signed
            case .error:
                return .Error
            }
        }
    }

    @IBOutlet private var editBarButton: UIBarButtonItem!
    private weak var loadingAlertView: UIAlertController?

    private var storedCustomRequest: [CustomRequest] = (NSArray.init(contentsOfFile: GlobalConstants.customRequestDataFilePath) as? [[String : Any]])?.flatMap {CustomRequest($0)} ?? []
    private var modifiedList: Bool = false

    private weak var currentRequest: TSSRequest?

    var numberOfRequest: Int {
        return self.storedCustomRequest.count
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(saveListData(_:)), name: .UIApplicationWillResignActive, object: UIApplication.shared)
        self.tableView.tableFooterView = UIView(frame: .zero)
        if #available(iOS 9.0, *), self.traitCollection.forceTouchCapability == .available {
            registerForPreviewing(with: self, sourceView: self.tableView)
        }
        if #available(iOS 11.0, *) {
            self.tableView.dropDelegate = self
        }
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.tableView.isEditing = false
        self.saveListData(nil)
    }
    // MARK: - Helpers
    typealias BackgroundSigningStatus = (model: String, version: String, status: SigningStatus)
    typealias TSSRequestRange = (from: Int, to: Int) // exclusive
    func checkSigningStatusInBackground(range: TSSRequestRange, completionHandler: @escaping ([BackgroundSigningStatus]) -> Void) {
        let refreshRange = self.storedCustomRequest[range.from..<range.to]

        var resultArray: [BackgroundSigningStatus] = []
        let serialQueue = DispatchQueue(label: "", qos: .userInitiated)
        let group = DispatchGroup()
        for customRequest in refreshRange {
            DispatchQueue.global(qos: .userInitiated).async(group: group) {
                let request = TSSRequest(firmwareURL: customRequest.buildManifestURL, deviceBoardConfiguration: customRequest.deviceBoard)
                var error: NSError?
                let timeout: TimeInterval = 15
                // Each request must finish within 15 seconds to avoid being killed by watchdog.
                serialQueue.asyncAfter(deadline: .now() + timeout, execute: {
                    request.cancelGlobalConnection()
                })
                let statusCode = request.checkSigningStatusWithError(&error)
                let newResult = FetchedTSSResult(currentStatus: FetchedTSSResult.firmwareSigningStatusConverter(statusCode), lastRefreshedDate: Date(), localizedErrorMessage: error?.localizedDescription)
                customRequest.status = newResult
                DispatchQueue.main.sync {
                    resultArray.append((model: request.deviceModel!, version: request.version!, status: newResult.currentStatus))
                }
            }
        }
        group.notify(queue: DispatchQueue.main) {
            completionHandler(resultArray)
        }
    }

    // not perform on main queue
    // completionHandler will be called after finish each request.
    private func checkAllSigningStatus(completionHandler: ((Int, SigningStatus) -> Bool)? = nil) {
        // only refresh status when current status is error or 30 sec after last refreshed.
        let sessionExpirationIntervalInSeconds: TimeInterval = 30
        for (index, customRequest) in self.storedCustomRequest.enumerated() {
            guard customRequest.status.currentStatus == .Error || (customRequest.status.lastRefreshedDate?.timeIntervalSinceNow ?? sessionExpirationIntervalInSeconds).magnitude >= sessionExpirationIntervalInSeconds else {continue}
            let request = TSSRequest(firmwareURL: customRequest.buildManifestURL, deviceBoardConfiguration: customRequest.deviceBoard)
            request.delegate = self
            self.currentRequest = request
            var error: NSError?
            let status = request.checkSigningStatusWithError(&error)
            guard self.loadingAlertView != nil else {return}
            customRequest.status = FetchedTSSResult(currentStatus: FetchedTSSResult.firmwareSigningStatusConverter(status), lastRefreshedDate: Date(), localizedErrorMessage: error?.localizedDescription)
            if !(completionHandler?(index, customRequest.status.currentStatus) ?? true) {
                break
            }
        }
    }
    private func loadFirmwareURLString(_ urlInString: String) {
        func validateURLInString(_ string: String) -> Bool {
            if let url = URL(string: string), UIApplication.shared.canOpenURL(url) {
                return true
            }
            return false
        }
        guard validateURLInString(urlInString) else {
            let errorView = UIAlertController(title: LocalizedString.errorTitle, message: "Invalid URL. ", preferredStyle: .alert)
            errorView.addAction(UIAlertAction(title: "OK", style: .cancel))
            self.present(errorView, animated: true)
            return
        }
        let request = TSSRequest(firmwareURL: urlInString)
        request.delegate = self
        let loadingView = UIAlertController(title: "Checking...", message: "", preferredStyle: .alert)
        loadingView.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
            request.cancelGlobalConnection()
        }))

        self.loadingAlertView = loadingView
        self.present(loadingView, animated: true) {
            DispatchQueue.global().async {
                let URLError = request.firmwareURLError
                DispatchQueue.main.async {
                    loadingView.dismiss(animated: false, completion: {
                        if let URLError = URLError as NSError? {
                            let errorView = UIAlertController(title: LocalizedString.errorTitle, message: "An error has occurred. Code: \(URLError.code). \(URLError.localizedDescription)", preferredStyle: .alert)
                            errorView.addAction(UIAlertAction(title: "OK", style: .default))
                            self.present(errorView, animated: true)
                            return
                        }
                        guard let supportedDevices = request.supportedDevices, !supportedDevices.isEmpty else {
                            let alertView = UIAlertController(title: LocalizedString.errorTitle, message: "No supported devices found in BuildManifest.", preferredStyle: .alert)
                            alertView.addAction(UIAlertAction(title: "OK", style: .cancel))
                            self.present(alertView, animated: true)
                            return
                        }
                        func createNewRequest(_ device: String) {
                            request.selectDevice(inSupportedList: device)
                            self.storedCustomRequest.append(CustomRequest(deviceBoard: request.deviceBoardConfig!, deviceModel: request.deviceModel!, version: request.version!, buildID: request.buildID!, buildManifestURL: urlInString, isOTA: request.isOTAVersion))
                            self.modifiedList = true
                            self.tableView.reloadData()
                        }
                        // let user pick one device model if there are more than one available.
                        if supportedDevices.count == 1 {
                            createNewRequest(supportedDevices[0])
                        }
                        else {
                            let selectionAlertView = UIAlertController(title: "Select a device", message: nil, preferredStyle: .alert)
                            supportedDevices.forEach({ (deviceModelString) in
                                let action = UIAlertAction(title: deviceModelString, style: .default, handler: { (action) in
                                    createNewRequest(action.title!)
                                })
                                selectionAlertView.addAction(action)
                                if #available(iOS 9.0, *), deviceModelString.contains(GlobalConstants.localProductType) && (!deviceModelString.contains("(") || deviceModelString.contains(GlobalConstants.localDeviceBoard)) {
                                    selectionAlertView.preferredAction = action
                                }
                            })
                            selectionAlertView.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                            self.present(selectionAlertView, animated: true)
                        }
                    })
                }
            }
        }
    }
    private func checkSigningStatus(At index: Int, presentingViewController: UIViewController? = nil, completionHandler: (() -> Void)? = nil) {
        let customRequest = self.storedCustomRequest[index]
        let refreshPrompt = UIAlertController(title: "Checking signing status for \(customRequest.version + "- \(customRequest.buildID)")...", message: "", preferredStyle: .alert)
        self.loadingAlertView = refreshPrompt
        let request = TSSRequest(firmwareURL: customRequest.buildManifestURL, deviceBoardConfiguration: customRequest.deviceBoard)
        request.delegate = self
        refreshPrompt.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
            request.cancelGlobalConnection()
        }))
        (presentingViewController ?? self).present(refreshPrompt, animated: true) {
            var hapticGenerator: AnyObject?
            if #available(iOS 10.0, *) {
                let _hapticGenerator = UINotificationFeedbackGenerator()
                _hapticGenerator.prepare()
                hapticGenerator = _hapticGenerator
            }
            request.checkSigningStatus { (status, error) in
                guard self.loadingAlertView != nil else {return}
                customRequest.status = FetchedTSSResult(currentStatus: FetchedTSSResult.firmwareSigningStatusConverter(status), lastRefreshedDate: Date(), localizedErrorMessage: error?.localizedDescription)
                DispatchQueue.main.async {
                    if #available(iOS 10.0, *) {
                        (hapticGenerator as? UINotificationFeedbackGenerator)?.notificationOccurred(error == nil ? .success : .error)
                        hapticGenerator = nil
                    }
                    self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
                    self.loadingAlertView?.dismiss(animated: true, completion: completionHandler)
                }
            }
        }
    }

    // MARK: - Actions

    @IBAction private func checkAllSigningStatus(_ sender: UIRefreshControl) {
        let refreshPrompt = UIAlertController(title: "Checking signing status for all firmwares...", message: "", preferredStyle: .alert)
        self.loadingAlertView = refreshPrompt
        refreshPrompt.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
            self.currentRequest?.cancelGlobalConnection()
            self.tableView.reloadData()
            sender.endRefreshing()
        }))
        self.present(refreshPrompt, animated: true) {
            var feedbackGenerator: AnyObject?
            if #available(iOS 10.0, *) {
                feedbackGenerator = UINotificationFeedbackGenerator()
            }
            DispatchQueue.global().async {
                self.checkAllSigningStatus() { (index, status) in
                    var refreshing = false
                    DispatchQueue.main.sync {
                        if #available(iOS 10.0, *), let feedbackGenerator = feedbackGenerator as? UINotificationFeedbackGenerator {
                            feedbackGenerator.notificationOccurred(status == .Error ? .error : .success)
                            feedbackGenerator.prepare()
                        }
                        refreshing = sender.isRefreshing
                        self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
                    }
                    return refreshing
                }
                DispatchQueue.main.async {
                    feedbackGenerator = nil
                    self.tableView.reloadData()
                    sender.endRefreshing()
                    self.loadingAlertView?.dismiss(animated: true)
                }
            }
        }
    }

    @IBAction private func addButtonTriggered(_ sender: UIBarButtonItem) {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Select from table", style: .default, handler: { (_) in
            self.performSegue(withIdentifier: "ToSelectFirmware", sender: self)
        }))
        actionSheet.addAction(UIAlertAction(title: "Enter URL manually", style: .default, handler: { (_) in
            let alertView = UIAlertController(title: "", message: "Enter a URL for iOS Firmware/OTA: ", preferredStyle: .alert)
            alertView.addTextField { (textField) in
                textField.placeholder = "BuildManifest URL"
                textField.keyboardType = .URL
                textField.clearButtonMode = .always
            }
            alertView.addAction(.init(title: "Cancel", style: .cancel))
            alertView.addAction(.init(title: "OK", style: .default, handler: { [unowned alertView] (_) in
                self.loadFirmwareURLString((alertView.textFields?.first?.text)!)
            }))
            self.present(alertView, animated: true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        self.present(actionSheet, animated: true)
    }
    @discardableResult
    @objc private func saveListData(_ sender: Any?) -> Bool {
        // potentially data unsafe but efficient
        if self.modifiedList {
            self.modifiedList = false
            return (self.storedCustomRequest.map{$0.archivableDictionary} as NSArray).write(toFile: GlobalConstants.customRequestDataFilePath, atomically: true)
        }
        return false
    }
    @IBAction private func editButtonPressed(_ sender: UIBarButtonItem?) {
        if self.tableView.isEditing {
            self.tableView.setEditing(false, animated: true)
            self.editBarButton.title = "Edit"
        }
        else {
            self.tableView.setEditing(true, animated: true)
            self.editBarButton.title = "Done"
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let cfivc = segue.destination as? CustomFirmwareInfoViewController, let sender = sender as? UITableViewCell {
            let indexPath = self.tableView.indexPath(for: sender)!
            cfivc.firmwareInfo = self.storedCustomRequest[indexPath.row]
            cfivc.delegate = self
            cfivc.indexInPreviousTableView = indexPath
        }
        else if let sftvc = (segue.destination as? UINavigationController)?.viewControllers.first as? SelectFirmwareTableViewController {
            sftvc.actionAfterAppeared = sftvc.loadListAllDevices
            sftvc.loadFirmwareActionBlock = self.loadFirmwareURLString
        }
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
extension CustomFirmwareTableViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.storedCustomRequest.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "custom", for: indexPath)
        let info = self.storedCustomRequest[indexPath.row]

        cell.textLabel?.text = info.description
        switch (info.status.currentStatus) {
            case .Signed:
                cell.backgroundColor = UIColor.green
                cell.detailTextLabel?.text = "This firmware is being signed."
            case .Not_Signed:
                cell.backgroundColor = UIColor.red
                cell.detailTextLabel?.text = "This firmware is not being signed."
            case .Unknown:
                cell.backgroundColor = UIColor.white
                cell.detailTextLabel?.text = "The signing status of this firmware is unknown."
            case .Error:
                cell.backgroundColor = UIColor.gray
                cell.detailTextLabel?.text = "An error has occurred when querying signing status."
        }
        return cell
    }

    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            self.modifiedList = true
            self.storedCustomRequest.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }

    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
        self.modifiedList = true
        self.storedCustomRequest.insert(self.storedCustomRequest.remove(at: fromIndexPath.row), at: to.row)
    }

    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let refresh = UITableViewRowAction(style: .normal, title: "Refresh") { (_, indexPath) in
            tableView.isEditing = false
            self.refreshItem(InViewController: nil, at: indexPath)
        }
        refresh.backgroundColor = UIColor.blue
        let delete = UITableViewRowAction(style: .destructive, title: "Remove") { (_, indexPath) in
            self.deleteItem(at: indexPath)
        }
        return [delete, refresh]
    }
}
extension CustomFirmwareTableViewController : TSSRequestDelegate {
    func request(_ request: TSSRequest, sendMessageOutput output: String) {
        DispatchQueue.main.async {
            if output.last == "\n" {
                self.loadingAlertView?.message = String(output.dropLast())
            }
        }
    }
}
@available(iOS 11.0, *)
extension CustomFirmwareTableViewController : UITableViewDropDelegate {
    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        let _ = coordinator.session.loadObjects(ofClass: String.self) { (items) in
            if let item = items.first {
                self.loadFirmwareURLString(item)
            }
        }
    }
    func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: String.self)
    }
    func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
        if tableView.hasActiveDrag {
            if session.items.count > 1 {
                return UITableViewDropProposal(operation: .cancel)
            }
            return UITableViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
        }
        return UITableViewDropProposal(operation: .copy)
    }
}
@available(iOS 9.0, *)
extension CustomFirmwareTableViewController : UIViewControllerPreviewingDelegate {
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        guard let indexPath = self.tableView.indexPathForRow(at: location) else {return nil}
        let firmwareInfoVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "Custom Firmware Info") as! CustomFirmwareInfoViewController
        previewingContext.sourceRect = self.tableView.rectForRow(at: indexPath)
        firmwareInfoVC.firmwareInfo = self.storedCustomRequest[indexPath.row]
        firmwareInfoVC.delegate = self
        firmwareInfoVC.indexInPreviousTableView = indexPath
        return firmwareInfoVC
    }

    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        self.show(viewControllerToCommit, sender: nil)
    }
}
extension CustomFirmwareTableViewController : CustomFirmwareInfoViewControllerDelegate {
    func deleteItem(at indexPath: IndexPath) {
        self.tableView(self.tableView, commit: .delete, forRowAt: indexPath)
    }
    func refreshItem(InViewController cfivc: CustomFirmwareInfoViewController?, at indexPath: IndexPath, completionHandler: (() -> Void)? = nil) {
        self.checkSigningStatus(At: indexPath.row, presentingViewController: cfivc) {
            cfivc?.firmwareInfo = self.storedCustomRequest[indexPath.row]
            completionHandler?()
        }
    }
    
    func finishedLabelSetting(text: String, at indexPath: IndexPath) {
        let customRequest = self.storedCustomRequest[indexPath.row]
        let oldLabel = customRequest.label ?? ""
        self.modifiedList = oldLabel != text
        guard self.modifiedList else {return}
        customRequest.label = text.isEmpty ? nil : text
        self.tableView.reloadRows(at: [indexPath], with: UITableViewRowAnimation.none)
    }
}
