//
//  SelectFirmwareTableViewController.swift
//  MobileTSS
//
//  Created by User on 9/6/19.
//

import UIKit

class SelectFirmwareTableViewController: UITableViewController {
    static let storyBoardIdentifier = "SelectFirmwareTVC"

    var actionAfterAppeared: (() -> Void)?
    var loadFirmwareActionBlock: ((String) -> Void)!

    @IBOutlet private weak var cancelBarButton: UIBarButtonItem?

    struct CellSelectItem : Comparable {
        static func <(lhs: CellSelectItem, rhs: CellSelectItem) -> Bool {
            for index in 0..<min(lhs.versionNums.count, rhs.versionNums.count) {
                if lhs.versionNums[index] == rhs.versionNums[index] {
                    continue
                }
                return lhs.versionNums[index] < rhs.versionNums[index]
            }
            return lhs.versionNums.count < rhs.versionNums.count
        }

        static func ==(lhs: CellSelectItem, rhs: CellSelectItem) -> Bool {
            return lhs.versionNums == rhs.versionNums
        }

        let title: String
        let subtitle: String
        let info: Any?

        private let versionNums: [Int]
        init(title: String, subtitle: String, versionDelimiter: Character, info: Any?) {
            self.title = title
            self.subtitle = subtitle
            let numbers = title[title.index { ("0"..."9").contains($0)}!...].split(separator: versionDelimiter)
            self.versionNums = numbers.flatMap {Int($0)}
            self.info = info
        }
    }
    private weak var loadingTask: URLSessionTask?

    private var actionBlockAfterTapCell: ((IndexPath) -> Void)?
    private var sectionTitles: [String]?
    private var itemList: [[CellSelectItem]] = []

    func loadListAllDevices() {
        var request = URLRequest(url: URL(string: "https://api.ipsw.me/v4/devices")!)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.navigationItem.title = "Devices"
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
            }
            if let error = error as NSError? {
                guard error.code != NSURLErrorCancelled else {return}
                DispatchQueue.main.async {
                    let alertView = UIAlertController(title: LocalizedString.errorTitle, message: "An error has occurred when loading list of all devices. \(error.localizedDescription)", preferredStyle: .alert)
                    alertView.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                        self.cancelButtonTapped(nil)
                    })
                    self.present(alertView, animated: true)
                }
                return
            }
            if let data = data, let loadedDictionary = (try? JSONSerialization.jsonObject(with: data)) as? [[String : Any]] {
                enum DeviceType : String {
                    case iPhone
                    case iPad
                    case iPod
                    init?(rawValue: String) {
                        if rawValue.starts(with: "iPhone") {
                            self = .iPhone
                        }
                        else if rawValue.starts(with: "iPad") {
                            self = .iPad
                        }
                        else if rawValue.starts(with: "iPod") {
                            self = .iPod
                        }
                        else {
                            return nil
                        }
                    }
                }
                var groupedDevices: [String: [CellSelectItem]] = [:]
                loadedDictionary.flatMap { device -> (DeviceType, CellSelectItem)? in
                    guard let id = device[JsonKeys.identifier_Key] as? String, let type = DeviceType(rawValue: id), let name = device[JsonKeys.name_Key] as? String else {
                        return nil
                    }
                    return (type, CellSelectItem(title: id, subtitle: name, versionDelimiter: ",", info: nil))
                }.forEach { (device) in
                    let type: String = device.0.rawValue
                    if groupedDevices[type] == nil {
                        groupedDevices[type] = [device.1]
                    }
                    else {
                        groupedDevices[type]?.append(device.1)
                    }
                }
                self.sectionTitles = groupedDevices.keys.sorted()
                self.itemList = self.sectionTitles!.map {groupedDevices[$0]!.sorted()}
                self.actionBlockAfterTapCell = { [unowned self] indexPath in
                    let sftvc = self.storyboard?.instantiateViewController(withIdentifier: SelectFirmwareTableViewController.storyBoardIdentifier) as! SelectFirmwareTableViewController
                    let itemList = self.itemList
                    sftvc.actionAfterAppeared = { [unowned sftvc] in
                        sftvc.loadListOfAllVersion(for: itemList[indexPath.section][indexPath.row].title)
                    }
                    sftvc.loadFirmwareActionBlock = self.loadFirmwareActionBlock
                    self.navigationController?.pushViewController(sftvc, animated: true)
                }
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
            else {
                DispatchQueue.main.async {
                    let alertView = UIAlertController(title: LocalizedString.errorTitle, message: "An error has occurred when parsing data from server.", preferredStyle: .alert)
                    alertView.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                        self.cancelButtonTapped(nil)
                    })
                    self.present(alertView, animated: true)
                }
            }
        }
        self.loadingTask = task
        task.resume()
    }
    private func loadListOfAllVersion(for deviceIdentifier: String) {
        var request = URLRequest(url: URL(string: "https://api.ipsw.me/v4/device/\(deviceIdentifier)")!)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.navigationItem.title = "Firmwares"
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                if self.firstViewController == false {
                    self.navigationItem.rightBarButtonItem = nil
                }
            }
            if let error = error as NSError? {
                guard error.code != NSURLErrorCancelled else {return}
                DispatchQueue.main.async {
                    let alertView = UIAlertController(title: LocalizedString.errorTitle, message: "An error has occurred when loading list of all firmwares. \(error.localizedDescription)", preferredStyle: .alert)
                    alertView.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                        self.cancelButtonTapped(nil)
                    })
                    self.present(alertView, animated: true)
                }
                return
            }
            if let data = data, let loadedDictionary = (((try? JSONSerialization.jsonObject(with: data)) as? [String : Any])?[JsonKeys.firmwares_Key]) as? [[String : Any]] {
                self.sectionTitles = nil
                self.itemList = [loadedDictionary.flatMap { (firmwareDict) -> CellSelectItem? in
                    guard let version = firmwareDict[JsonKeys.version_Key] as? String,
                        let buildID = firmwareDict[JsonKeys.buildid_Key] as? String,
                        let url = firmwareDict[JsonKeys.url_Key] as? String else { return nil }
                    return CellSelectItem(title: version, subtitle: buildID, versionDelimiter: ".", info: url)
                }.sorted().reversed()]
                self.actionBlockAfterTapCell = { [unowned self] indexPath in
                    let itemList = self.itemList
                    self.dismiss(animated: true) { [unowned self] in
                        self.loadFirmwareActionBlock(itemList[indexPath.section][indexPath.row].info as! String)
                    }
                }
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
            else {
                DispatchQueue.main.async {
                    let alertView = UIAlertController(title: LocalizedString.errorTitle, message: "An error has occurred when parsing data from server.", preferredStyle: .alert)
                    alertView.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                        self.cancelButtonTapped(nil)
                    })
                    self.present(alertView, animated: true)
                }
            }
        }
        self.loadingTask = task
        task.resume()
    }
    private func loadListOfAllBetaVersion(for deviceIdentifier: String) {
        // TODO:
    }
    private func loadListOfAllOTAVersion(for deviceIdentifier: String) {
        var request = URLRequest(url: URL(string: "https://api.ipsw.me/v4/device/\(deviceIdentifier)")!)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.navigationItem.title = "OTAs"
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                if self.firstViewController == false {
                    self.navigationItem.rightBarButtonItem = nil
                }
            }
            if let error = error as NSError? {
                guard error.code != NSURLErrorCancelled else {return}
                DispatchQueue.main.async {
                    let alertView = UIAlertController(title: LocalizedString.errorTitle, message: "An error has occurred when loading list of all firmwares. \(error.localizedDescription)", preferredStyle: .alert)
                    alertView.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                        self.cancelButtonTapped(nil)
                    })
                    self.present(alertView, animated: true)
                }
                return
            }
            if let data = data, let loadedDictionary = (((try? JSONSerialization.jsonObject(with: data)) as? [String : Any])?[JsonKeys.firmwares_Key]) as? [[String : Any]] {
                self.sectionTitles = nil
                self.itemList = [loadedDictionary.flatMap { (firmwareDict) -> CellSelectItem? in
                    guard let version = firmwareDict[JsonKeys.version_Key] as? String,
                        let buildID = firmwareDict[JsonKeys.buildid_Key] as? String,
                        let url = firmwareDict[JsonKeys.url_Key] as? String else { return nil }
                    return CellSelectItem(title: version, subtitle: buildID, versionDelimiter: ".", info: url)
                    }.sorted().reversed()]
                self.actionBlockAfterTapCell = { [unowned self] indexPath in
                    let itemList = self.itemList
                    self.dismiss(animated: true) { [unowned self] in
                        self.loadFirmwareActionBlock(itemList[indexPath.section][indexPath.row].info as! String)
                    }
                }
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
            else {
                DispatchQueue.main.async {
                    let alertView = UIAlertController(title: LocalizedString.errorTitle, message: "An error has occurred when parsing data from server.", preferredStyle: .alert)
                    alertView.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                        self.cancelButtonTapped(nil)
                    })
                    self.present(alertView, animated: true)
                }
            }
        }
        self.loadingTask = task
        task.resume()
    }
    @IBAction private func cancelButtonTapped(_ sender: Any?) {
        loadingTask?.cancel()
        if firstViewController {
            self.dismiss(animated: true)
        }
        else {
            self.navigationController?.popViewController(animated: true)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if firstViewController == false {
            self.navigationItem.rightBarButtonItem = self.navigationItem.leftBarButtonItem
            self.navigationItem.leftBarButtonItem = nil
        }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        cancelBarButton?.isEnabled = true
        actionAfterAppeared?()
        actionAfterAppeared = nil
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        loadingTask?.cancel()
    }

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sectionTitles?.count ?? 1
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionTitles != nil ? sectionTitles![section] : nil
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return itemList.isEmpty == false ? itemList[section].count : 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "item", for: indexPath)
        cell.textLabel?.text = self.itemList[indexPath.section][indexPath.row].title
        cell.detailTextLabel?.text = self.itemList[indexPath.section][indexPath.row].subtitle
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        actionBlockAfterTapCell?(indexPath)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
extension UIViewController {
    var firstViewController: Bool {
        return self.navigationController?.viewControllers.first === self
    }
}
