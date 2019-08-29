//
//  SHSHDetailsViewController.swift
//  MobileTSS
//
//  Created by User on 12/31/18.
//

import UIKit
import LocalAuthentication

class SHSHDetailsViewController: UIViewController {

    var shshInfo: SHSHViewController.SHSHInfo!
    var deleteSHSHAndUpdateTableViewCallback: (() -> Void)!

    @IBOutlet private weak var tableView: UITableView!

    private weak var loadingAlertView: UIAlertController?

    private var shshFile: SHSHFile?
    private var shshBasicInfo: [(String, String)] = []

    private var imageInfoData: [String : [String : Any]]?

    private var clipboardString: String?

    private lazy var sectionTitles : [String]? = self.imageInfoData?.keys.sorted()
    private lazy var subsectionTitles: [String : [String]]? = self.imageInfoData?.mapValues {$0.keys.sorted()}

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(menuButtonTapped(_:)))
        do {
            let shshFile = try SHSHFile(contentsOfFile: self.shshInfo.path)
            self.shshFile = shshFile
            self.imageInfoData = shshFile.manifestBody
            self.shshBasicInfo.append(("Version", String(shshFile.version)))
            if let generator = shshFile.generator {
                self.shshBasicInfo.append(("Generator", generator))
            }
            if let deviceModel = shshInfo.deviceModel {
                shshFile.verifyGenerator = !isNonceEntanglingEnabledForModel(deviceModel)
            }
            self.tableView.reloadData()
        } catch let error {
            let alertView = UIAlertController(title: LocalizedString.errorTitle, message: "An error has occurred when read data from SHSH. \(error.localizedDescription)", preferredStyle: .alert)
            alertView.addAction(UIAlertAction(title: "OK", style: .cancel))
            self.present(alertView, animated: true)
        }
        // Do any additional setup after loading the view.
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.becomeFirstResponder()
    }
    private func deleteSHSHFile() {
        do {
            try FileManager.default.removeItem(atPath: self.shshInfo.path)
            self.navigationController?.popViewController(animated: true)
            self.deleteSHSHAndUpdateTableViewCallback()
        } catch let error {
            let alertView = UIAlertController(title: LocalizedString.errorTitle, message: "Cannot delete shsh file. \(error.localizedDescription)", preferredStyle: .alert)
            alertView.addAction(UIAlertAction(title: "OK", style: .cancel))
            self.present(alertView, animated: true)
        }
    }
    private func askURLForVerification(WithMessage message: String? = nil) {
        let alertView = UIAlertController(title: nil, message: "Please enter the \(self.shshInfo.isOTA ? "OTA" : "firmware") URL corresponding to this SHSH.", preferredStyle: .alert)
        if let message = message {
            alertView.message = alertView.message! + message
        }
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
            loadingView.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
                request.cancelGlobalConnection()
            }))
            self.loadingAlertView = loadingView
            self.present(loadingView, animated: true) {
                DispatchQueue.global().async {
                    let URLError = request.firmwareURLError
                    DispatchQueue.main.async {
                        loadingView.dismiss(animated: true) {
                            if let URLError = URLError as NSError? {
                                let errorView = UIAlertController(title: LocalizedString.errorTitle, message: "An error has occurred. Code: \(URLError.code). \(URLError.localizedDescription)", preferredStyle: .alert)
                                errorView.addAction(UIAlertAction(title: "OK", style: .default))
                                self.present(errorView, animated: true)
                                return
                            }
                            if request.deviceBoardConfig != nil, let buildIdentity = request.currentBuildIdentity {
                                // deviceBoard is known, then verify identity.
                                var error: NSError?
                                let result = self.shshFile!.verify(with: buildIdentity, error: &error)
                                self.showVerificationResult(result, message: error?.localizedDescription)
                            }
                            else if let supportedDevices = request.supportedDevices, !supportedDevices.isEmpty {
                                func verify(_ device: String) {
                                    request.selectDevice(inSupportedList: device)
                                    var error: NSError?
                                    DispatchQueue.global(qos: .userInitiated).async {
                                        let identity: TSSBuildIdentity = request.currentBuildIdentity!
                                        let result = self.shshFile!.verify(with: identity, error: &error)
                                        //                                        self.shshInfo.deviceBoard = identity.deviceBoardConfiguration
                                        //                                        self.shshInfo.deviceModel = request.deviceModel!
                                        //                                        self.shshInfo.apnonce = self.shshFile?.apnonce!
                                        //                                        self.shshInfo.isOTA = request.isOTAVersion
                                        //                                        self.shshInfo.version = request.version!
                                        //                                        self.shshInfo.buildID = request.buildID!
                                        //                                        self.shshInfo.ecid = self.shshFile!.
                                        DispatchQueue.main.async {
                                            self.showVerificationResult(result, message: error?.localizedDescription)
                                        }
                                    }
                                }
                                if supportedDevices.count == 1 {
                                    // only one model.
                                    verify(supportedDevices[0])
                                }
                                else if supportedDevices.count > 1 {
                                    // ask users if more than one models are avaiable.
                                    let modelPromptView = UIAlertController(title: nil, message: "Select a device for SHSH file.", preferredStyle: .alert)
                                    supportedDevices.forEach({ (device) in
                                        modelPromptView.addAction(UIAlertAction(title: device, style: .default, handler: { (_) in
                                            verify(device)
                                        }))
                                    })
                                    modelPromptView.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                                    self.present(modelPromptView, animated: true)
                                }
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
        }))
        self.present(alertView, animated: true)
    }
    
    private func showVerificationResult(_ result: Bool, message: String? = nil) {
        let alertView: UIAlertController = UIAlertController(title: "Verification Result", message: nil, preferredStyle: .alert)
        alertView.message = result ? "✅ This SHSH file is valid and usable. " : "❌ This SHSH file is not valid and probably unsafe to use. "
        if let message = message {
            alertView.message = alertView.message! + message
        }
        alertView.addAction(UIAlertAction(title: "OK", style: .cancel))
        alertView.addAction(UIAlertAction(title: "Show Log", style: .default, handler: { (_) in
            self.performSegue(withIdentifier: "showLog", sender: nil)
        }))
        self.present(alertView, animated: true)
    }
    @objc private func menuButtonTapped(_ sender: UIBarButtonItem) {
        let selectionActionSheet = UIAlertController(title: nil, message: self.shshInfo.fileName, preferredStyle: .actionSheet)
        selectionActionSheet.popoverPresentationController?.barButtonItem = sender
        if let shshFile = shshFile, shshFile.isVerificationSupported {
            selectionActionSheet.addAction(UIAlertAction(title: "Verify", style: .default, handler: { (_) in
                if !self.shshInfo.isOTA,
                    let deviceModel = self.shshInfo.deviceModel,
                    let version = self.shshInfo.version,
                    let buildID = self.shshInfo.buildID {
                    // check wanted buildmanifest is in local first.
                    if let matchedBuildManifest = NSDictionary.init(contentsOfFile: "\(GlobalConstants.buildManifestDirectoryPath)\(deviceModel)_\(version)-\(buildID)") as? [String : Any] {
                        if let deviceBoard = self.shshInfo.deviceBoard {
                            if let identity = TSSBuildIdentity(buildManifest: matchedBuildManifest, deviceBoard: deviceBoard) {
                                // boardconfig is known, check if identity is ok to use; if not download a new one.
                                var error: NSError?
                                let result = shshFile.verify(with: identity, error: &error)
                                self.showVerificationResult(result, message: error?.localizedDescription)
                                return
                            }
                        }
                        else {
                            let buildIdentitiesForModel = TSSBuildIdentity.buildIdentities(inBuildManifest: matchedBuildManifest, forDeviceModel: deviceModel)
                            // if nil || empty array then buildmanifest is probably broken; download a new one.
                            if let buildIdentitiesForModel = buildIdentitiesForModel, !buildIdentitiesForModel.isEmpty {
                                if buildIdentitiesForModel.count == 1 {
                                    // only one model.
                                    var error: NSError?
                                    let result = shshFile.verify(with: buildIdentitiesForModel[0], error: &error)
                                    if result {
                                        self.shshInfo.deviceBoard = buildIdentitiesForModel[0].deviceBoardConfiguration
                                    }
                                    self.showVerificationResult(result, message: error?.localizedDescription)
                                }
                                else {
                                    // ask users if more than one models are avaiable.
                                    let modelPromptView = UIAlertController(title: nil, message: "Select a board for SHSH file.", preferredStyle: .alert)
                                    buildIdentitiesForModel.forEach({ (identity) in
                                        modelPromptView.addAction(UIAlertAction(title: identity.deviceBoardConfiguration, style: .default, handler: { (_) in
                                            var error: NSError?
                                            let result = shshFile.verify(with: identity, error: &error)
                                            if result {
                                                self.shshInfo.deviceBoard = identity.deviceBoardConfiguration
                                            }
                                            self.showVerificationResult(result, message: error?.localizedDescription)
                                        }))
                                    })
                                    modelPromptView.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                                    self.present(modelPromptView, animated: true)
                                }
                                return
                            }
                            // an error has occurred when read buildidentities.
                        }
                    }
                    // get firmware url from remote and download if buildmanifest is not present in local or is unusable.
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
                        }
                        else if let data = data, let urlString = (((try? JSONSerialization.jsonObject(with: data)) as? [String : Any])?[JsonKeys.url_Key] as? String) {
                            let request = TSSRequest(firmwareURL: urlString, deviceBoardConfiguration: self.shshInfo.deviceBoard)
                            request.delegate = self
                            DispatchQueue.main.sync {
                                self.loadingAlertView?.title = "Downloading BuildManifest from URL..."
                                cancelCallback = {
                                    //                                    print("Canceling tssrequest.")
                                    request.cancelGlobalConnection()
                                }
                            }
                            let connectionError = request.firmwareURLError
                            let buildIdentity = request.currentBuildIdentity
                            DispatchQueue.main.async {
                                self.loadingAlertView?.dismiss(animated: true) {
                                    if let connectionError = connectionError {
                                        let errorView = UIAlertController(title: LocalizedString.errorTitle, message: "An error has occurred when reaching destination URL. \(connectionError.localizedDescription)", preferredStyle: .alert)
                                        errorView.addAction(UIAlertAction(title: "OK", style: .default))
                                        self.present(errorView, animated: true)
                                        return
                                    }
                                    if request.deviceBoardConfig != nil, let buildIdentity = buildIdentity {
                                        // deviceBoard is known, then verify identity.
                                        var error: NSError?
                                        let result = shshFile.verify(with: buildIdentity, error: &error)
                                        self.showVerificationResult(result, message: error?.localizedDescription)
                                        //                                        return
                                    }
                                    else if let supportedDevices = request.supportedDevices?.filter({$0.contains(deviceModel)}), !supportedDevices.isEmpty {
                                        // remove other irrelevant models.
                                        func verify(_ device: String) {
                                            request.selectDevice(inSupportedList: device)
                                            var error: NSError?
                                            DispatchQueue.global(qos: .userInitiated).async {
                                                let identity: TSSBuildIdentity = request.currentBuildIdentity!
                                                let result = shshFile.verify(with: identity, error: &error)
                                                if result {
                                                    self.shshInfo.deviceBoard = identity.deviceBoardConfiguration
                                                }
                                                DispatchQueue.main.async {
                                                    self.showVerificationResult(result, message: error?.localizedDescription)
                                                }
                                            }
                                        }
                                        if supportedDevices.count == 1 {
                                            // only one model.
                                            verify(supportedDevices[0])
                                            return
                                        }
                                        if supportedDevices.count > 1 {
                                            // ask users if more than one models are avaiable.
                                            let modelPromptView = UIAlertController(title: nil, message: "Select a board for SHSH file.", preferredStyle: .alert)
                                            supportedDevices.forEach({ (device) in
                                                modelPromptView.addAction(UIAlertAction(title: device, style: .default, handler: { (_) in
                                                    verify(device)
                                                }))
                                            })
                                            modelPromptView.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                                            self.present(modelPromptView, animated: true)
                                            return
                                        }
                                    }
                                    else {
                                        let alertView = UIAlertController(title: LocalizedString.errorTitle, message: "Cannot get matched model and boardconfig in buildmanifest from URL.", preferredStyle: .alert)
                                        alertView.addAction(UIAlertAction(title: "OK", style: .default))
                                        self.present(alertView, animated: true)
                                    }
                                }
                            }
                        }
                        else {
                            // ipsw.me does not know that firmware, probably betas.
                            DispatchQueue.main.async {
                                self.loadingAlertView?.dismiss(animated: true) {
                                    self.askURLForVerification()
                                }
                            }
                        }
                    }
                    let downloadView = UIAlertController(title: "Querying firmware URL from remote...", message: nil, preferredStyle: .alert)
                    downloadView.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
                        cancelCallback?()
                    }))
                    cancelCallback = {
                        //                        print("Canceling urlrequest...")
                        task.cancel()
                    }
                    self.loadingAlertView = downloadView
                    self.present(downloadView, animated: true) {
                        task.resume()
                    }
                }
                else {
                    // ota shsh or nothing is known.
                    self.askURLForVerification()
                }
            }))
        }
        selectionActionSheet.addAction(UIAlertAction(title: "Share", style: .default, handler: { _ in
            let activityVC = UIActivityViewController(activityItems: [URL(fileURLWithPath: self.shshInfo.path)], applicationActivities: nil)
            activityVC.popoverPresentationController?.barButtonItem = sender
            self.present(activityVC, animated: true)
        }))
        selectionActionSheet.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { (_) in
            let alertView = UIAlertController(title: "Warning", message: "Do you want to delete this shsh file? This operation cannot be undone.", preferredStyle: .alert)
            alertView.addAction(UIAlertAction(title: "No", style: .cancel))
            alertView.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: { (_) in
                let context = LAContext()
                var policy: LAPolicy?
                if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
                    policy = .deviceOwnerAuthenticationWithBiometrics
                }
                else if #available(iOS 9.0, *), context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) {
                    policy = .deviceOwnerAuthentication
                }
                guard policy != nil else {
                    self.deleteSHSHFile()
                    return
                }
                context.evaluatePolicy(policy!, localizedReason: "MobileTSS needs authentication to delete shsh file.", reply: { (success, error) in
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
        self.present(selectionActionSheet, animated: true)
    }


    @IBAction func longPressToCopy(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else {
            return
        }
        let point: CGPoint = sender.location(in: sender.view)
        if let indexPath = self.tableView.indexPathForRow(at: point), let cell = self.tableView.cellForRow(at: indexPath) as? ScrollableLabelTableViewCell {
            if cell.scrollView.point(inside: self.tableView.convert(point, to: cell.scrollView), with: nil) {
                let menuController = UIMenuController.shared
                var targetRect = cell.scrollView.frame
                let labelFrameInCell = cell.scrollView.convert(cell.scrollView.subviews.first {$0 is UILabel}!.frame, to: cell)
                if labelFrameInCell.size.width < targetRect.size.width {
                    targetRect.origin.x = labelFrameInCell.origin.x
                    targetRect.size.width = labelFrameInCell.size.width
                }
                menuController.setTargetRect(targetRect, in: cell)
                menuController.setMenuVisible(true, animated: true)
                self.clipboardString = cell.rightSideScrollableText
            }
        }
    }
    @objc override func copy(_ sender: Any?) {
        if let clipboardString = self.clipboardString {
            UIPasteboard.general.string = clipboardString
            self.clipboardString = nil
        }
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let povc = segue.destination as? ProgressOutputViewController, let log = self.shshFile?.log {
            povc.configurationBlock = {[unowned povc] in
                povc.addTextToOutputView(log)
                povc.topTitle = "Log"
                povc.backButtonTitle = "Done"
            }
        }
    }
}
extension SHSHDetailsViewController : UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.imageInfoData == nil ? "blank" : "info", for: indexPath)
        if let cell = cell as? ScrollableLabelTableViewCell {
            if indexPath.section == 0 {
                cell.leftSideText = self.shshBasicInfo[indexPath.row].0
                cell.rightSideScrollableText = self.shshBasicInfo[indexPath.row].1
            }
            else {
                let sectionTitle = self.sectionTitles![indexPath.section - 1]
                let subsectionTitle = self.subsectionTitles![sectionTitle]![indexPath.row]
                cell.leftSideText = subsectionTitle
                cell.rightSideScrollableText = "\(self.imageInfoData![sectionTitle]![subsectionTitle]!)"
            }
        }
        return cell
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        guard let sectionTitles = self.sectionTitles else { return 1 }
        return sectionTitles.count + 1
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let imageInfoData = self.imageInfoData else { return 1 }
        return section != 0 ? imageInfoData[self.sectionTitles![section - 1]]!.count : self.shshBasicInfo.count
    }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? nil : self.sectionTitles?.first
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return self.imageInfoData == nil ? 0 : 44
    }
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if self.shshFile?.imageType == .IMG3 {
            return "Viewing manifest info is not supported for IMG3."
        }
        return self.imageInfoData == nil ? "An error has occurred when read manifest data from SHSH." : nil
    }
    func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        if let view = view as? UITableViewHeaderFooterView {
            view.textLabel?.textAlignment = .center
        }
    }
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard section > 0, let sectionTitles = self.sectionTitles, let view = view as? UITableViewHeaderFooterView else {return}
        view.textLabel?.text = sectionTitles[section - 1]
        view.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
    }
}
extension SHSHDetailsViewController : TSSRequestDelegate {
    func request(_ request: TSSRequest, sendMessageOutput output: String) {
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
