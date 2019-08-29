//
//  APNonceTableViewController.swift
//  MobileTSS
//
//  Created by User on 1/27/19.
//

import UIKit

class APNonceListTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet private weak var tableView: UITableView!
    private var customAPNonceGenList: [[String : String]] = (NSArray(contentsOfFile: GlobalConstants.customAPNonceGenListFilePath) as? [[String : String]]) ?? []

    private var isModified = false
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.tableFooterView = UIView()
        NotificationCenter.default.addObserver(self, selector: #selector(saveData(_:)), name: NSNotification.Name.UIApplicationWillResignActive, object: UIApplication.shared)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addButtonTapped(_:)))
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.saveData(self)
    }
    @objc private func saveData(_ sender: Any?) {
        if isModified {
            (self.customAPNonceGenList as NSArray).write(toFile: GlobalConstants.customAPNonceGenListFilePath, atomically: true)
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.customAPNonceGenList.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "item", for: indexPath)
        let (apnonce, generator) = (self.customAPNonceGenList[indexPath.row][CustomAPGenKey.APNonce_Key], self.customAPNonceGenList[indexPath.row][CustomAPGenKey.Generator_Key])
        cell.textLabel?.text = nil
        cell.detailTextLabel?.text = nil
        if let generator = generator {
            cell.textLabel?.text = generator
            cell.detailTextLabel?.text = apnonce
        }
        else {
            cell.textLabel?.text = apnonce
        }
        return cell
    }
    @objc private func addButtonTapped(_ sender: UIBarButtonItem) {
        self.performSegue(withIdentifier: "ToEdit", sender: nil)
    }
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            self.customAPNonceGenList.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            self.isModified = true
        }
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.performSegue(withIdentifier: "ToEdit", sender: indexPath)
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let apetvc = segue.destination as? APNonceEditTableViewController {
            let indexPath = sender as? IndexPath
            apetvc.apgenInfo = indexPath == nil ? [:] : self.customAPNonceGenList[indexPath!.row]
            apetvc.finishEditingCallback = { [unowned self] apgenInfo in
                guard !apgenInfo.isEmpty else {
                    if let indexPath = indexPath {
                        // remove apnonce & generator in existing list
                        self.customAPNonceGenList.remove(at: indexPath.row)
                        self.tableView.deleteRows(at: [indexPath], with: .automatic)
                        self.isModified = true
                    }
                    return
                }
                if let indexPath = indexPath {
                    let original = self.customAPNonceGenList[indexPath.row]
                    if original != apgenInfo {
                        self.isModified = true
                        self.customAPNonceGenList[indexPath.row] = apgenInfo
                        self.tableView.reloadRows(at: [indexPath], with: .automatic)
                    }
                }
                else {
                    self.isModified = true
                    self.customAPNonceGenList.append(apgenInfo)
                    self.tableView.insertRows(at: [IndexPath.init(row: self.customAPNonceGenList.count - 1, section: 0)], with: .automatic)
                }
            }
        }
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
