//
//  CustomFirmwareTableViewController.swift
//  MobileTSS
//
//  Created by User on 7/24/18.
//

import UIKit

class CustomFirmwareTableViewController: UITableViewController {
    enum SigningStatus {
        case signed
        case notSigned
        case unknown    // default, when a new request is created.
        case error  // an error has occurred
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
            
            return Array(zip([LocalizedString.identifier, LocalizedString.board, LocalizedString.version, LocalizedString.buildid], [deviceModel, deviceBoard, version, buildID]))
        }

        fileprivate var archivableDictionary: [String : Any] {
            var dict = [ArchivableKeys.BuildManifestURL_Key: buildManifestURL,
                        ArchivableKeys.BuildID_Key: buildID,
                        ArchivableKeys.Version_Key: version,
                        ArchivableKeys.isOTAVersion_Key: isOTA,
                        ArchivableKeys.DeviceModel_Key: deviceModel,
                        ArchivableKeys.DeviceBoard_Key: deviceBoard] as [String : Any]
            if let label = label {
                dict[ArchivableKeys.Label_Key] = label
            }
            return dict
        }
        fileprivate var description: String {
            return label ?? "\(deviceModel) - \(version) (\(buildID))\(isOTA ? " - OTA" : "")"
        }

        init(deviceBoard: String, deviceModel: String, version: String, buildID: String, buildManifestURL: String, isOTA: Bool, status: FetchedTSSResult? = nil) {
            self.deviceBoard = deviceBoard
            self.deviceModel = deviceModel
            self.version = version
            self.buildID = buildID
            self.isOTA = isOTA
            self.buildManifestURL = buildManifestURL
            self.status = status ?? FetchedTSSResult(currentStatus: .unknown)
        }

        fileprivate init?(_ archivedDictionary: [String : Any]) {
            guard let deviceModel = archivedDictionary[ArchivableKeys.DeviceModel_Key] as? String,
                let version = archivedDictionary[ArchivableKeys.Version_Key] as? String,
                let buildID = archivedDictionary[ArchivableKeys.BuildID_Key] as? String,
                let buildManifestURL = archivedDictionary[ArchivableKeys.BuildManifestURL_Key] as? String, { () -> Bool in
                    if let buildManifestURL = URL(string: buildManifestURL) {
                        return UIApplication.shared.canOpenURL(buildManifestURL)
                    }
                    return false
                }() else { return nil }
            if let deviceBoard = archivedDictionary[ArchivableKeys.DeviceBoard_Key] as? String {
                self.deviceBoard = deviceBoard
            }
            else if let foundBoard = findDeviceInfoForSpecifiedModel(deviceModel)?.pointee.deviceBoardConfiguration {
                // !!!: might cause board mismatch problem.
                deviceBoard = String(cString: foundBoard)
            }
            else {
                return nil
            }
            self.deviceModel = deviceModel
            self.version = version
            self.buildID = buildID
            self.buildManifestURL = buildManifestURL
            isOTA = archivedDictionary[ArchivableKeys.isOTAVersion_Key] as? Bool ?? false
            label = archivedDictionary[ArchivableKeys.Label_Key] as? String
            status = FetchedTSSResult(currentStatus: .unknown)
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
    }

    @IBOutlet private var editBarButton: UIBarButtonItem!
    private weak var loadingAlertView: UIAlertController?

    private var storedCustomRequest: [CustomRequest] = (NSArray(contentsOfFile: GlobalConstants.customRequestDataFilePath) as? [[String : Any]])?.compactMap {CustomRequest($0)} ?? []
    private var modifiedList: Bool = false

    private weak var currentRequest: TSSRequest?
    private var viewAppearedAction: (() -> Void)?
    var numberOfRequest: Int {
        return storedCustomRequest.count
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(saveListData(_:)), name: UIApplication.willResignActiveNotification, object: UIApplication.shared)
        tableView.tableFooterView = UIView(frame: .zero)
        tableView.dropDelegate = self
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewAppearedAction?()
        viewAppearedAction = nil
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        tableView.isEditing = false
        saveListData(nil)
    }
    // MARK: - Helpers
    struct BackgroundSigningStatus {
        var model: String
        var version: String
        var status: SigningStatus
    }
    typealias TSSRequestRange = (from: Int, to: Int) // exclusive
    func checkSigningStatusInBackground(range: TSSRequestRange, completionHandler: @escaping ([BackgroundSigningStatus]) -> Void) {
        let refreshRange = storedCustomRequest[range.from..<range.to]

        var resultArray: [BackgroundSigningStatus] = []
        let serialQueue = DispatchQueue(label: "BFSerialQ", qos: .userInitiated)
        let group = DispatchGroup()
        for customRequest in refreshRange {
            DispatchQueue.global(qos: .userInitiated).async(group: group) {
                let request = TSSRequest(firmwareURL: customRequest.buildManifestURL, deviceBoardConfiguration: customRequest.deviceBoard)
                var error: NSError?
                let timeout: TimeInterval = 15
                // Each request must finish within 15 seconds (hard deadline) to avoid being killed by watchdog.
                serialQueue.asyncAfter(deadline: .now() + timeout) {
                    print("Timeout: cancelling request")
                    request.cancel()
                }
                let statusCode = request.checkSigningStatusWithError(&error)
                let newResult = FetchedTSSResult(currentStatus: SigningStatus(firmwareSigningStatus: statusCode), lastRefreshedDate: Date(), localizedErrorMessage: error?.localizedDescription)
                customRequest.status = newResult
                DispatchQueue.main.sync {
                    resultArray.append(BackgroundSigningStatus(model: request.deviceModel!, version: request.firmwareVersion!.version, status: newResult.currentStatus))
                }
            }
        }
        group.notify(queue: .main) {
            completionHandler(resultArray)
        }
    }

    // not perform on main queue
    // completionHandler will be called after finish each request.
    private func checkAllSigningStatus(completionHandler: ((Int, SigningStatus) -> Bool)? = nil) {
        // only refresh status when current status is error or 30 sec after last refreshed.
        let sessionExpirationIntervalInSeconds: TimeInterval = 30
        for (index, customRequest) in storedCustomRequest.enumerated() {
            guard customRequest.status.currentStatus == .error || (customRequest.status.lastRefreshedDate?.timeIntervalSinceNow ?? sessionExpirationIntervalInSeconds).magnitude >= sessionExpirationIntervalInSeconds else {continue}
            let request = TSSRequest(firmwareURL: customRequest.buildManifestURL, deviceBoardConfiguration: customRequest.deviceBoard)
            request.delegate = self
            currentRequest = request
            var error: NSError?
            let status = request.checkSigningStatusWithError(&error)
            guard loadingAlertView != nil else {return}
            customRequest.status = FetchedTSSResult(currentStatus: SigningStatus(firmwareSigningStatus: status), lastRefreshedDate: Date(), localizedErrorMessage: error?.localizedDescription)
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
            present(errorView, animated: true)
            return
        }
        let request = TSSRequest(firmwareURL: urlInString)
        request.delegate = self
        let loadingView = UIAlertController(title: "Checking...", message: "", preferredStyle: .alert)
        loadingView.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
            request.cancel()
        }))

        loadingAlertView = loadingView
        present(loadingView, animated: true) {
            request.validateURL { (result, error) in
                DispatchQueue.main.async {
                    loadingView.dismiss(animated: false) {
                        if let error = error as NSError? {
                            let errorView = UIAlertController(title: LocalizedString.errorTitle, message: "An error has occurred. Code: \(error.code). \(error.localizedDescription)", preferredStyle: .alert)
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
                        func createNewRequestAtIndex(_ index: Int) {
                            request.selectDeviceInSupportedList(at: UInt(index))
                            let firmwareVersion = request.firmwareVersion!
                            self.storedCustomRequest.append(CustomRequest(deviceBoard: request.deviceBoardConfig!, deviceModel: request.deviceModel!, version: firmwareVersion.version, buildID: firmwareVersion.buildID, buildManifestURL: urlInString, isOTA: firmwareVersion.isOTAFirmware))
                            self.modifiedList = true
                            self.tableView.reloadData()
                        }

                        // let user pick one device model if there are more than one available.
                        if supportedDevices.count == 1 {
                            createNewRequestAtIndex(0)
                        }
                        else {
                            let selectionAlertView = UIAlertController(title: "Select a device", message: nil, preferredStyle: .alert)

                            for (index, string) in supportedDevices.enumerated() {
                                let action = UIAlertAction(title: string, style: .default) { _ in
                                    createNewRequestAtIndex(index)
                                }
                                selectionAlertView.addAction(action)
                                let profile = PreferencesManager.shared.preferredProfile
                                if string.contains(profile.deviceModel) && (!string.contains("(") || string.contains(profile.deviceBoard)) {
                                    selectionAlertView.preferredAction = action
                                }
                            }
                            selectionAlertView.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                            self.present(selectionAlertView, animated: true)
                        }
                    }
                }
            }
        }
    }
    private func checkSigningStatus(At index: Int, presentingViewController: UIViewController? = nil, completionHandler: (() -> Void)? = nil) {
        let customRequest = storedCustomRequest[index]
        let refreshPrompt = UIAlertController(title: "Checking signing status for \(customRequest.version + "- \(customRequest.buildID)")...", message: "", preferredStyle: .alert)
        loadingAlertView = refreshPrompt
        let request = TSSRequest(firmwareURL: customRequest.buildManifestURL, deviceBoardConfiguration: customRequest.deviceBoard)
        request.delegate = self
        refreshPrompt.addAction(UIAlertAction(title: "Cancel", style: .cancel) { (_) in
            request.cancel()
        })
        (presentingViewController ?? self).present(refreshPrompt, animated: true) {
            let hapticGenerator = UINotificationFeedbackGenerator()
            hapticGenerator.prepare()
            request.checkSigningStatus { (status, error) in
                guard self.loadingAlertView != nil else {return}
                customRequest.status = FetchedTSSResult(currentStatus: SigningStatus(firmwareSigningStatus: status), lastRefreshedDate: Date(), localizedErrorMessage: error?.localizedDescription)
                DispatchQueue.main.async {
                    hapticGenerator.notificationOccurred(error == nil ? .success : .error)
                    if self.view.window == nil {
                        self.viewAppearedAction = {
                            self.tableView.reloadData()
                        }
                    }
                    else {
                        self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
                    }
                    self.loadingAlertView?.dismiss(animated: true, completion: completionHandler)
                }
            }
        }
    }

    // MARK: - Actions

    @IBAction private func checkAllSigningStatus(_ sender: UIRefreshControl) {
        let refreshPrompt = UIAlertController(title: "Checking signing status for all firmwares...", message: "", preferredStyle: .alert)
        loadingAlertView = refreshPrompt
        refreshPrompt.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
            self.currentRequest?.cancel()
            self.tableView.reloadData()
            sender.endRefreshing()
        }))
        present(refreshPrompt, animated: true) {
            let feedbackGenerator = UINotificationFeedbackGenerator()
            feedbackGenerator.prepare()
            DispatchQueue.global().async {
                self.checkAllSigningStatus() { (index, status) in
                    var refreshing = false
                    DispatchQueue.main.sync {
                        feedbackGenerator.notificationOccurred(status == .error ? .error : .success)
                        feedbackGenerator.prepare()
                        refreshing = sender.isRefreshing
                        self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
                    }
                    return refreshing
                }
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    sender.endRefreshing()
                    self.loadingAlertView?.dismiss(animated: true)
                }
            }
        }
    }

    @IBAction private func addButtonTriggered(_ sender: UIBarButtonItem) {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        actionSheet.popoverPresentationController?.barButtonItem = sender
        actionSheet.addAction(UIAlertAction(title: "Select from table", style: .default, handler: { (_) in
            self.performSegue(withIdentifier: "ToSelectFirmware", sender: self)
        }))
        actionSheet.addAction(UIAlertAction(title: "Select from web page", style: .default, handler: { (_) in
            self.performSegue(withIdentifier: "ToWebpage", sender: self)
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
        present(actionSheet, animated: true)
    }
    @discardableResult
    @objc private func saveListData(_ sender: Any?) -> Bool {
        // potentially data unsafe but efficient
        if modifiedList {
            modifiedList = false
            return (storedCustomRequest.map{$0.archivableDictionary} as NSArray).write(toFile: GlobalConstants.customRequestDataFilePath, atomically: true)
        }
        return false
    }
    @IBAction private func editButtonPressed(_ sender: UIBarButtonItem?) {
        if tableView.isEditing {
            tableView.setEditing(false, animated: true)
            editBarButton.title = "Edit"
        }
        else {
            tableView.setEditing(true, animated: true)
            editBarButton.title = "Done"
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let cfivc = segue.destination as? CustomFirmwareInfoTableViewController, let sender = sender as? UITableViewCell {
            let indexPath = tableView.indexPath(for: sender)!
            cfivc.firmwareInfo = storedCustomRequest[indexPath.row]
            cfivc.delegate = self
            cfivc.indexInPreviousTableView = indexPath
        }
        else if let sftvc = (segue.destination as? UINavigationController)?.viewControllers.first as? SelectFirmwareTableViewController {
            sftvc.actionAfterAppeared = sftvc.loadListAllDevices
            sftvc.loadFirmwareActionBlock = loadFirmwareURLString
        }
        else if let wpvc = (segue.destination as? UINavigationController)?.viewControllers.first as? WebpageViewController {
            wpvc.loadFirmwareActionBlock = loadFirmwareURLString
        }
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
extension CustomFirmwareTableViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return storedCustomRequest.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "custom", for: indexPath)
        let info = storedCustomRequest[indexPath.row]

        cell.textLabel?.text = info.description
        switch (info.status.currentStatus) {
            case .signed:
                cell.imageView?.image = UIImage(named: "signed")
                cell.imageView?.tintColor = .systemGreen
                cell.detailTextLabel?.text = "This firmware is being signed."
            case .notSigned:
                cell.imageView?.image = UIImage(named: "unsigned")
                cell.imageView?.tintColor = .systemRed
                cell.detailTextLabel?.text = "This firmware is not being signed."
            case .unknown:
                cell.imageView?.image = nil
                cell.imageView?.tintColor = nil
                cell.detailTextLabel?.text = "The signing status of this firmware is unknown."
            case .error:
                cell.imageView?.image = UIImage(named: "error")
                cell.imageView?.tintColor = .systemYellow
                cell.detailTextLabel?.text = "An error has occurred when querying signing status."
        }
        return cell
    }

    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            modifiedList = true
            storedCustomRequest.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }

    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
        modifiedList = true
        storedCustomRequest.insert(storedCustomRequest.remove(at: fromIndexPath.row), at: to.row)
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
    func request(_ request: TSSRequest, verboseOutput output: String) {
        DispatchQueue.main.async {
            if output.last == "\n" {
                self.loadingAlertView?.message = String(output.dropLast())
            }
        }
    }
}
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
extension CustomFirmwareTableViewController : CustomFirmwareInfoViewControllerDelegate {
    func deleteItem(at indexPath: IndexPath) {
        tableView(tableView, commit: .delete, forRowAt: indexPath)
    }
    func refreshItem(InViewController cfivc: CustomFirmwareInfoTableViewController?, at indexPath: IndexPath, completionHandler: (() -> Void)? = nil) {
        checkSigningStatus(At: indexPath.row, presentingViewController: cfivc) {
            cfivc?.firmwareInfo = self.storedCustomRequest[indexPath.row]
            completionHandler?()
        }
    }
    
    func finishedLabelSetting(text: String, at indexPath: IndexPath) {
        let customRequest = storedCustomRequest[indexPath.row]
        let oldLabel = customRequest.label ?? ""
        modifiedList = oldLabel != text
        guard modifiedList else {return}
        customRequest.label = text.isEmpty ? nil : text
        tableView.reloadRows(at: [indexPath], with: UITableView.RowAnimation.none)
    }
}
extension CustomFirmwareTableViewController.SigningStatus {
    init(firmwareSigningStatus: TSSFirmwareSigningStatus) {
        switch firmwareSigningStatus {
        case .notSigned:
            self = .notSigned
        case .signed:
            self = .signed
        case .error:
            self = .error
        default:
            self = .unknown
        }
    }
}
