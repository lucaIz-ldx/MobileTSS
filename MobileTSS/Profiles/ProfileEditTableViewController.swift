//
//  ProfileEditTableViewController.swift
//  MobileTSS
//
//  Created by User on 12/6/19.
//

import UIKit

class ProfileEditTableViewController: UITableViewController {

    @IBOutlet private weak var ecidTextField: UITextField!

    @IBOutlet private weak var deviceInfoCell: UITableViewCell!
    @IBOutlet private weak var deviceModelLabel: UILabel!
    @IBOutlet private weak var deviceBoardLabel: UILabel!
    
    var isLocalProfile: Bool = false
    
    var finishEditingProfileBlock: ((DeviceProfile) -> Void)!
    var profile: DeviceProfile?

    override func viewDidLoad() {
        super.viewDidLoad()
        if let profile = profile {
            deviceModelLabel.text = profile.deviceModel
            deviceBoardLabel.text = profile.deviceBoard
            ecidTextField.text = profile.ecid
        }
        else {
            deviceModelLabel.textColor = .gray
            deviceBoardLabel.text = nil
            deviceModelLabel.text = "Tap to select model"
        }
        if profile == nil {
            navigationItem.title = "Add Profile"
        }
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
    }

    @IBAction private func saveButtonTapped(_ sender: UIBarButtonItem) {
        guard var profile = profile else {
            let alert = UIAlertController(title: LocalizedString.errorTitle, message: "You must select a device model before create new profile.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            present(alert, animated: true)
            return
        }
        if profile.updateECID(ecidTextField.text) {
            self.profile = profile
            navigationController?.popViewController(animated: true)
            DispatchQueue.main.async {
                self.finishEditingProfileBlock(profile)
            }
        }
        else {
            let alert = UIAlertController(title: LocalizedString.errorTitle, message: "Cannot parse ECID.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            present(alert, animated: true)
        }
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let psdtvc = (segue.destination as? UINavigationController)?.viewControllers.first as? ProfileSelectDeviceTableViewController {
            segue.destination.presentationController?.delegate = self
            psdtvc.selectProfileBlock = { [unowned self, unowned psdtvc] profile in
                psdtvc.dismiss(animated: true)
                self.presentationControllerWillDismiss(segue.destination.presentationController!)
                guard let profile = profile else { return }
                self.profile = profile
                self.deviceModelLabel.textColor = nil
                self.deviceModelLabel.text = profile.deviceModel
                self.deviceBoardLabel.text = profile.deviceBoard
                if let cell = sender as? UITableViewCell, let indexPath = self.tableView.indexPath(for: cell) {
                    self.tableView.deselectRow(at: indexPath, animated: true)
                }
            }
        }
        else if let nltvc = segue.destination as? APNonceListTableViewController {
            nltvc.currentProfile = profile
        }
    }
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 && isLocalProfile {
            return CGFloat.leastNonzeroMagnitude
        }
        return super.tableView(tableView, heightForHeaderInSection: section)
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 && isLocalProfile {
            return nil
        }
        return super.tableView(tableView, titleForHeaderInSection: section)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 && isLocalProfile {
            return 0
        }
        return super.tableView(tableView, numberOfRowsInSection: section)
    }
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        guard identifier == "ToNonceList" else {
            return super.shouldPerformSegue(withIdentifier: identifier, sender: sender)
        }
        guard let profile = profile else {
            let alertView = UIAlertController(title: "Missing Device Model", message: "You need to set device model before add apnonce/generator.", preferredStyle: .alert)
            alertView.addAction(.init(title: "OK", style: .cancel, handler: { (_) in
                self.tableView.deselectRow(at: IndexPath(row: 0, section: 2), animated: true)
            }))
            present(alertView, animated: true)
            return false
        }
        if profile.ecid == nil {
            let alertView = UIAlertController(title: "Missing ECID", message: "You need to set ECID before add apnonce/generator.", preferredStyle: .alert)
            alertView.addAction(.init(title: "OK", style: .cancel, handler: { (_) in
                self.tableView.deselectRow(at: IndexPath(row: 0, section: 2), animated: true)
            }))
            present(alertView, animated: true)
            return false
        }
        return super.shouldPerformSegue(withIdentifier: identifier, sender: sender)
    }
}
extension ProfileEditTableViewController : UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        guard (textField.text?.isEmpty ?? true) == false else {
            // do not parse if user clears ECID
            return false
        }
        if TSSECID(string: textField.text!) == nil {
            let alert = UIAlertController(title: LocalizedString.errorTitle, message: "Cannot parse ECID.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            present(alert, animated: true)
        }
        else {
            profile?.updateECID(textField.text)
        }
        return false
    }
}
extension ProfileEditTableViewController : UIAdaptivePresentationControllerDelegate {
    func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        if let selectedIndexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selectedIndexPath, animated: true)
        }
    }
}
