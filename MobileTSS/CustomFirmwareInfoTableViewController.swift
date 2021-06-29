//
//  CustomFirmwareInfoTableViewController.swift
//  MobileTSS
//
//  Created by User on 7/26/18.
//

import UIKit

protocol CustomFirmwareInfoViewControllerDelegate : class {
    func deleteItem(at index: IndexPath)
    func refreshItem(InViewController cfivc: CustomFirmwareInfoTableViewController?, at indexPath: IndexPath, completionHandler: (() -> Void)?)
    func finishedLabelSetting(text: String, at indexPath: IndexPath)
}
class CustomFirmwareInfoTableViewController: FirmwareInfoTableViewController {

    weak var delegate: CustomFirmwareInfoViewControllerDelegate?
    var indexInPreviousTableView: IndexPath!

    let footerViewHeight: CGFloat = 40

    private weak var loadingAlertView: UIAlertController?

    override var firmwareInfo: CustomFirmwareTableViewController.CustomRequest! {
        didSet {
            displayedInfo.append((CustomFirmwareTableViewController.CustomRequest.ArchivableKeys.Label_Key, firmwareInfo.label ?? ""))
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return displayedInfo.count
        }
        return (firmwareInfo.status.currentStatus == .signed && firmwareInfo.deviceBoard != PreferencesManager.shared.preferredProfile.deviceBoard) || (firmwareInfo.status.currentStatus == .notSigned) ? 1 : 2
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section == 1, let date = firmwareInfo.status.lastRefreshedDate else {return nil}
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return "Last updated: \(dateFormatter.string(from: date))"
    }

    override func firmwareInfoCellConfigure(_ cell: FirmwareInfoTableViewCell, At indexPath: IndexPath) {
        if displayedInfo[indexPath.row].0 == CustomFirmwareTableViewController.CustomRequest.ArchivableKeys.Label_Key {
            cell.rvalueEditable = true
            cell.contentTextField?.delegate = self
        }
        else {
            cell.rvalueEditable = false
            cell.contentTextField?.delegate = nil
        }
        super.firmwareInfoCellConfigure(cell, At: indexPath)
    }
    override func statusLabelCellConfigure(_ cell: StatusLabelTableViewCell, At indexPath: IndexPath) {
        // sign status
//        cell.contentView.subviews.forEach {$0.removeFromSuperview()}
//        cell.textLabel?.adjustsFontSizeToFitWidth = true
//        cell.textLabel?.textAlignment = .center
//        cell.textLabel?.minimumScaleFactor = 12/(cell.textLabel?.font.pointSize ?? 1)
//        cell.textLabel?.numberOfLines = 2
        let signingStatus = firmwareInfo.status.currentStatus
        let profile = PreferencesManager.shared.preferredProfile

        switch signingStatus {
        case .signed:
            cell.contentView.backgroundColor = UIColor.systemGreen
            var string = "This firmware is being signed. "
            if firmwareInfo.deviceBoard == profile.deviceBoard {
                string += "You can save blobs for this version. "
            }
            cell.label.text = string
        case .notSigned:
            cell.contentView.backgroundColor = UIColor.systemRed
            var string = "This firmware is not being signed. "
            if firmwareInfo.deviceBoard == profile.deviceBoard {
                string += "You cannot save blobs for this version. "
            }
            cell.label.text = string
        case .unknown:
            cell.contentView.backgroundColor = UIColor.white
            cell.label.text = "The signing status of this firmware is unknown."
        case .error:
            cell.contentView.backgroundColor = UIColor.systemYellow
            cell.label.text = "Cannot determine signing status of this firmware. \(firmwareInfo.status.localizedErrorMessage!)"
        }
    }
    override func buttonCellConfigure(_ cell: ButtonTableViewCell, At indexPath: IndexPath) {
        guard firmwareInfo.status.currentStatus != .signed else {
            super.buttonCellConfigure(cell, At: indexPath)
            return
        }
        if firmwareInfo.status.currentStatus == .error {
            cell.button.setTitle("Retry", for: .normal)
        }
        else {
            cell.button.setTitle("Refresh", for: .normal)
        }
        cell.button.removeTarget(nil, action: nil, for: .touchUpInside)
        cell.button.setTitleColor(UIColor.gray, for: .highlighted)
        cell.button.addTarget(self, action: #selector(refreshSigningStatus), for: .touchUpInside)
    }
    @objc private func refreshSigningStatus() {
        delegate?.refreshItem(InViewController: self, at: indexInPreviousTableView) {
            UIView.transition(with: self.tableView,
                              duration: 0.15,
                              options: .transitionCrossDissolve,
                              animations: { self.tableView.reloadData() })
        }
    }
}
extension CustomFirmwareInfoTableViewController {
    override var previewActionItems: [UIPreviewActionItem] {
        return [
            UIPreviewAction(title: "Refresh", style: .default, handler: { (_, previewViewController) in
                let pvc = (previewViewController as! CustomFirmwareInfoTableViewController)
                pvc.delegate?.refreshItem(InViewController: nil, at: pvc.indexInPreviousTableView, completionHandler: nil)
            }),
            UIPreviewAction(title: "Delete", style: .destructive, handler: { (_, previewViewController) in
                let pvc = (previewViewController as! CustomFirmwareInfoTableViewController)
                pvc.delegate?.deleteItem(at: pvc.indexInPreviousTableView)
            })
        ]
    }
}
extension CustomFirmwareInfoTableViewController : UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        delegate?.finishedLabelSetting(text: textField.text!, at: indexInPreviousTableView)
        return false
    }
}
