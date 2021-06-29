//
//  SHSHDetailsViewController.swift
//  MobileTSS
//
//  Created by User on 12/31/18.
//

import UIKit
import LocalAuthentication

class SHSHDetailsViewController: UIViewController {

    var shshInfo: SHSHTableViewController.SHSHInfo!
    var deleteSHSHAndUpdateTableViewCallback: (() -> Void)!

    @IBOutlet private weak var tableView: UITableView!

    private weak var loadingAlertView: UIAlertController?

    private var shshFile: SHSHFile?
    private var shshBasicInfo: [(String, String)] = []

    private var imageInfoData: [String : [String : Any]]?

    private var clipboardString: String?

    private lazy var sectionTitles : [String]? = imageInfoData?.keys.sorted()
    private lazy var subsectionTitles: [String : [String]]? = imageInfoData?.mapValues {$0.keys.sorted()}

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(menuButtonTapped(_:)))
        do {
            let shshFile = try SHSHFile(contentsOfFile: shshInfo.path)
            self.shshFile = shshFile
            imageInfoData = shshFile.manifestBody
            shshBasicInfo.append(("Version", String(shshFile.version)))
            if let generator = shshFile.generator {
                shshBasicInfo.append(("Generator", generator))
            }
            if let deviceModel = shshInfo.deviceModel {
                shshFile.verifyGenerator = !TSSNonce.isNonceEntanglingEnabled(forDeviceModel: deviceModel)
            }
            tableView.reloadData()
        } catch let error {
            let alertView = UIAlertController(title: LocalizedString.errorTitle, message: "An error has occurred when read data from SHSH. \(error.localizedDescription)", preferredStyle: .alert)
            alertView.addAction(UIAlertAction(title: "OK", style: .cancel))
            present(alertView, animated: true)
        }
        // Do any additional setup after loading the view.
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }
    private func deleteSHSHFile() {
        do {
            try FileManager.default.removeItem(atPath: shshInfo.path)
            CATransaction.begin()
            CATransaction.setCompletionBlock(deleteSHSHAndUpdateTableViewCallback)
            navigationController?.popViewController(animated: true)
            CATransaction.commit()
        } catch let error {
            let alertView = UIAlertController(title: LocalizedString.errorTitle, message: "Cannot delete shsh file. \(error.localizedDescription)", preferredStyle: .alert)
            alertView.addAction(UIAlertAction(title: "OK", style: .cancel))
            present(alertView, animated: true)
        }
    }
    private func verifyWithRequest(_ request: TSSRequest, deviceModel: String? = nil) {
        request.validateURL { (result, error) in
            DispatchQueue.main.async {
                self.loadingAlertView?.dismiss(animated: true) {
                    if let error = error {
                        let errorView = UIAlertController(title: LocalizedString.errorTitle, message: "An error has occurred when reaching destination URL. \(error.localizedDescription)", preferredStyle: .alert)
                        errorView.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(errorView, animated: true)
                        return
                    }
                    if let buildIdentity = request.currentBuildIdentity {
                        // deviceBoard is known, then verify identity.
                        var error: NSError?
                        let result = self.shshFile!.verify(with: buildIdentity, error: &error)
                        self.showVerificationResult(result, message: error?.localizedDescription)
                    }
                    else if var supportedDevices = request.supportedDevices, !supportedDevices.isEmpty {
                        if let deviceModel = deviceModel {
                            supportedDevices.removeAll {$0.contains(deviceModel)}
                        }
                        func verifyDeviceAtIndex(_ index: Int) {
                            request.selectDeviceInSupportedList(at: UInt(index))
                            var error: NSError?
                            self.showVerificationResult(self.shshFile!.verify(with: request.currentBuildIdentity!, error: &error), message: error?.localizedDescription)
                        }
                        guard supportedDevices.count > 1 else {
                            // only one model.
                            verifyDeviceAtIndex(0)
                            return
                        }
                        // ask users if more than one models are available.
                        let modelPromptView = UIAlertController(title: nil, message: "Select a board for SHSH file.", preferredStyle: .alert)
                        for (index, title) in supportedDevices.enumerated() {
                            modelPromptView.addAction(UIAlertAction(title: title, style: .default) { _ in
                                verifyDeviceAtIndex(index)
                            })
                        }
                        modelPromptView.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                        self.present(modelPromptView, animated: true)
                    }
                    else {
                        let alertView = UIAlertController(title: LocalizedString.errorTitle, message: "Cannot get matched model and boardconfig in buildmanifest from URL.", preferredStyle: .alert)
                        alertView.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(alertView, animated: true)
                    }
                }
            }
        }
    }
    private func askURLForVerification() {
        let alertView = UIAlertController(title: nil, message: "Please enter the \(shshInfo.isOTA ? "OTA" : "firmware") URL corresponding to this SHSH.", preferredStyle: .alert)
        alertView.addTextField { (textField) in
            textField.placeholder = "BuildManifest URL"
            textField.keyboardType = .URL
            textField.clearButtonMode = .always
        }
        alertView.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alertView.addAction(UIAlertAction(title: "OK", style: .default, handler: { [unowned alertView] (_) in
            let urlInString = (alertView.textFields?.first?.text)!
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
            let request = TSSRequest(firmwareURL: urlInString, deviceBoardConfiguration: self.shshInfo.deviceBoard)
            request.delegate = self
            let loadingView = UIAlertController(title: "Checking...", message: "", preferredStyle: .alert)
            loadingView.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                request.cancel()
            })
            self.loadingAlertView = loadingView
            self.present(loadingView, animated: true) {
                self.verifyWithRequest(request)
            }
        }))
        present(alertView, animated: true)
    }
    
    private func showVerificationResult(_ result: Bool, message: String? = nil) {
        let alertMessage: String = {
            var msg = result ? "✅ This SHSH file is valid and usable. " : "❌ This SHSH file is not valid and probably unsafe to use. "
            if let message = message {
                msg += message
            }
            return msg
        }()
        let alertView: UIAlertController = UIAlertController(title: "Verification Result", message: alertMessage, preferredStyle: .alert)
        alertView.addAction(UIAlertAction(title: "OK", style: .cancel))
        alertView.addAction(UIAlertAction(title: "Show Log", style: .default, handler: { (_) in
            self.performSegue(withIdentifier: "showLog", sender: nil)
        }))
        present(alertView, animated: true)
    }
    @objc private func menuButtonTapped(_ sender: UIBarButtonItem) {
        let selectionActionSheet = UIAlertController(title: nil, message: shshInfo.fileName, preferredStyle: .actionSheet)
        selectionActionSheet.popoverPresentationController?.barButtonItem = sender
        if let shshFile = shshFile, shshFile.isVerificationSupported {
            selectionActionSheet.addAction(UIAlertAction(title: "Verify", style: .default) { (_) in
                guard self.shshInfo.isOTA == false, let deviceModel = self.shshInfo.deviceModel, let version = self.shshInfo.version, let buildID = self.shshInfo.buildID else {
                    // ota shsh or nothing is known.
                    self.askURLForVerification()
                    return
                }
                // check if buildIdentity has been cached
                if let deviceBoard = self.shshInfo.deviceBoard, let buildIdentityData = try? Data(contentsOf: URL(fileURLWithPath: "\(GlobalConstants.buildManifestDirectoryPath + TSSBuildIdentity.buildIdentityCacheFileName(withDeviceBoard: deviceBoard, version: version, buildId: buildID))")), let identity = TSSBuildIdentity(buildIdentitiesData: buildIdentityData), identity.deviceBoardConfiguration == deviceBoard {
                    // boardconfig is known, check if identity is ok to use; if not download a new one.
                    var error: NSError?
                    let result = shshFile.verify(with: identity, error: &error)
                    self.showVerificationResult(result, message: error?.localizedDescription)
                    return
                }

                // get firmware url from remote in order to download buildmanifest
                let url = URL(string: "https://api.ipsw.me/v4/ipsw/\(deviceModel)/\(buildID)")!
                var request = URLRequest(url: url)
                request.addValue("application/json", forHTTPHeaderField: "Accept")
                var cancelCallback : (() -> Void)?
                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    guard self.loadingAlertView != nil else {return}
                    if let error = error {
                        DispatchQueue.main.async {
                            self.loadingAlertView?.dismiss(animated: true) {
                                let alertView = UIAlertController(title: LocalizedString.errorTitle, message: "An error has occurred when query firmware url from remote. \(error.localizedDescription)", preferredStyle: .alert)
                                alertView.addAction(UIAlertAction(title: "OK", style: .default))
                                self.present(alertView, animated: true)
                            }
                        }
                        return
                    }
                    guard let data = data, let urlString = (((try? JSONSerialization.jsonObject(with: data)) as? [String : Any])?[JsonKeys.url_Key] as? String) else {
                        // ipsw.me does not know about that firmware, probably betas.
                        DispatchQueue.main.async {
                            self.loadingAlertView?.dismiss(animated: true, completion: self.askURLForVerification)
                        }
                        return
                    }

                    // download buildmanifest from firmware URL
                    let request = TSSRequest(firmwareURL: urlString, deviceBoardConfiguration: self.shshInfo.deviceBoard)
                    request.delegate = self
                    cancelCallback = {
                        request.cancel()
                    }
                    DispatchQueue.main.sync {
                        self.loadingAlertView?.title = "Downloading BuildManifest from URL..."
                    }
                    self.verifyWithRequest(request, deviceModel: deviceModel)
                }
                let downloadView = UIAlertController(title: "Querying firmware URL from remote...", message: "", preferredStyle: .alert)
                downloadView.addAction(UIAlertAction(title: "Cancel", style: .cancel) { (_) in
                    cancelCallback?()
                })
                cancelCallback = {
                    task.cancel()
                }
                self.loadingAlertView = downloadView
                self.present(downloadView, animated: true) {
                    task.resume()
                }
            })
        }
        selectionActionSheet.addAction(UIAlertAction(title: "Share", style: .default, handler: { _ in
            let activityVC = UIActivityViewController(activityItems: [URL(fileURLWithPath: self.shshInfo.path)], applicationActivities: nil)
            activityVC.popoverPresentationController?.barButtonItem = sender
            self.present(activityVC, animated: true)
        }))
        if UIApplication.shared.canOpenURL(URL(string: "filza://")!) {
            selectionActionSheet.addAction(UIAlertAction(title: "Show in Filza", style: .default) { (_) in
                UIApplication.shared.open(URL(string: "filza://view\(self.shshInfo.path)")!)
            })
        }
        selectionActionSheet.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { (_) in
            let alertView = UIAlertController(title: "Delete SHSH", message: "Do you want to delete this shsh file? This operation cannot be undone.", preferredStyle: .alert)
            alertView.addAction(UIAlertAction(title: "No", style: .cancel))
            alertView.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: { (_) in
                let context = LAContext()
                guard let policy: LAPolicy = {
                    if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
                        return .deviceOwnerAuthenticationWithBiometrics
                    }
                    if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) {
                        return .deviceOwnerAuthentication
                    }
                    return nil
                    }() else {
                        self.deleteSHSHFile()
                        return
                }
                context.evaluatePolicy(policy, localizedReason: "MobileTSS needs authentication to delete shsh file.", reply: { (success, error) in
                    if success {
                        DispatchQueue.main.async {
                            self.deleteSHSHFile()
                        }
                    }
                })
            }))
            self.present(alertView, animated: true)
        }))
        selectionActionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(selectionActionSheet, animated: true)
    }

    @IBAction func longPressToCopy(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else {
            return
        }
        let point: CGPoint = sender.location(in: sender.view)
        if let indexPath = tableView.indexPathForRow(at: point), let cell = tableView.cellForRow(at: indexPath) as? ScrollableLabelTableViewCell {
            if cell.scrollView.point(inside: tableView.convert(point, to: cell.scrollView), with: nil) {
                let menuController = UIMenuController.shared
                var targetRect = cell.scrollView.frame
                let labelFrameInCell = cell.scrollView.convert(cell.scrollView.subviews.first {$0 is UILabel}!.frame, to: cell)
                if labelFrameInCell.size.width < targetRect.size.width {
                    targetRect.origin.x = labelFrameInCell.origin.x
                    targetRect.size.width = labelFrameInCell.size.width
                }
                menuController.setTargetRect(targetRect, in: cell)
                menuController.setMenuVisible(true, animated: true)
                clipboardString = cell.rightSideScrollableText
            }
        }
    }
    @objc override func copy(_ sender: Any?) {
        if let clipboardString = clipboardString {
            UIPasteboard.general.string = clipboardString
            self.clipboardString = nil
        }
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let povc = segue.destination as? ProgressOutputViewController, let log = shshFile?.log {
            povc.configurationBlock = { [unowned povc] in
                povc.addTextToOutputView(log)
                povc.topTitle = "Log"
                povc.backButtonTitle = "Done"
            }
        }
    }
}
extension SHSHDetailsViewController : UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: imageInfoData == nil ? "blank" : "info", for: indexPath)
        if let cell = cell as? ScrollableLabelTableViewCell {
            if indexPath.section == 0 {
                cell.leftSideText = shshBasicInfo[indexPath.row].0
                cell.rightSideScrollableText = shshBasicInfo[indexPath.row].1
            }
            else {
                let sectionTitle = sectionTitles![indexPath.section - 1]
                let subsectionTitle = subsectionTitles![sectionTitle]![indexPath.row]
                cell.leftSideText = subsectionTitle
                cell.rightSideScrollableText = "\(imageInfoData![sectionTitle]![subsectionTitle]!)"
            }
        }
        return cell
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        guard let sectionTitles = sectionTitles else { return 1 }
        return sectionTitles.count + 1
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let imageInfoData = imageInfoData else { return 1 }
        return section != 0 ? imageInfoData[sectionTitles![section - 1]]!.count : shshBasicInfo.count
    }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? nil : sectionTitles?.first
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return imageInfoData == nil ? 0 : 44
    }
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if shshFile?.imageType == .IMG3 {
            return "Viewing manifest info is not supported for IMG3."
        }
        return imageInfoData == nil ? "An error has occurred when read manifest data from SHSH." : nil
    }
    func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        if let view = view as? UITableViewHeaderFooterView {
            view.textLabel?.textAlignment = .center
        }
    }
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard section > 0, let sectionTitles = sectionTitles, let view = view as? UITableViewHeaderFooterView else {return}
        view.textLabel?.text = sectionTitles[section - 1]
        view.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
    }
}
extension SHSHDetailsViewController : TSSRequestDelegate {
    func request(_ request: TSSRequest, verboseOutput output: String) {
        DispatchQueue.main.async {
            self.loadingAlertView?.message = output.last == "\n" ? String(output.dropLast()) : output
        }
    }
}
extension SHSHDetailsViewController {
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return action == #selector(copy(_:))
    }
    override var canBecomeFirstResponder: Bool {
        return true
    }
}
