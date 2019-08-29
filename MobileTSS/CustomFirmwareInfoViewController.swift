//
//  CustomFirmwareInfoViewController.swift
//  MobileTSS
//
//  Created by User on 7/26/18.
//

import UIKit

protocol CustomFirmwareInfoViewControllerDelegate : class {
    func deleteItem(at index: IndexPath)
    func refreshItem(InViewController cfivc: CustomFirmwareInfoViewController?, at indexPath: IndexPath, completionHandler: (() -> Void)?)
    func finishedLabelSetting(text: String, at indexPath: IndexPath)
}
class CustomFirmwareInfoViewController: FirmwareInfoViewController {

    weak var delegate: CustomFirmwareInfoViewControllerDelegate?
    var indexInPreviousTableView: IndexPath!

    @IBOutlet private var customInfoTableView: UITableView!

    let footerViewHeight: CGFloat = 40

    private weak var loadingAlertView: UIAlertController?
    override func viewDidLoad() {
        super.tableView = self.customInfoTableView
        super.viewDidLoad()
        self.displayedKeys.append(CustomFirmwareTableViewController.CustomRequest.ArchivableKeys.Label_Key)
        self.displayedValue.append(self.firmwareInfo.label ?? "")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return self.displayedKeys.count
        }
        return (self.firmwareInfo.status.currentStatus == .Signed && self.firmwareInfo.deviceBoard != GlobalConstants.localDeviceBoard) || (self.firmwareInfo.status.currentStatus == .Not_Signed) ? 1 : 2
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section == 1, let date = self.firmwareInfo.status.lastRefreshedDate else {return nil}
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return "Last updated: \(dateFormatter.string(from: date))"
    }

    override func firmwareInfoCellConfigure(_ cell: FirmwareInfoTableViewCell, At indexPath: IndexPath) {
        if self.displayedKeys[indexPath.row] == CustomFirmwareTableViewController.CustomRequest.ArchivableKeys.Label_Key {
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
        //                    cell.contentView.subviews.forEach {$0.removeFromSuperview()}
        //                    cell.textLabel?.adjustsFontSizeToFitWidth = true
        //                    cell.textLabel?.textAlignment = .center
        //                    cell.textLabel?.minimumScaleFactor = 12/(cell.textLabel?.font.pointSize ?? 1)
        //                    cell.textLabel?.numberOfLines = 2
        let signingStatus = self.firmwareInfo.status.currentStatus
        switch signingStatus {
        case .Signed:
            cell.backgroundColor = UIColor.green
            var string = "This firmware is being signed. "
            if self.firmwareInfo.deviceBoard == GlobalConstants.localDeviceBoard {
                string += "You can save blobs for this version. "
            }
            cell.label.text = string
        case .Not_Signed:
            cell.backgroundColor = UIColor.red
            var string = "This firmware is not being signed. "
            if self.firmwareInfo.deviceBoard == GlobalConstants.localDeviceBoard {
                string += "You cannot save blobs for this version. "
            }
            cell.label.text = string
        case .Unknown:
            cell.backgroundColor = UIColor.white
            cell.label.text = "The signing status of this firmware is unknown."
        case .Error:
            cell.backgroundColor = UIColor.gray
            cell.label.text = "Cannot determine signing status of this firmware. \(self.firmwareInfo.status.localizedErrorMessage!)"
        }
    }
    override func buttonCellConfigure(_ cell: ButtonTableViewCell, At indexPath: IndexPath) {
        guard self.firmwareInfo.status.currentStatus != .Signed else {
            super.buttonCellConfigure(cell, At: indexPath)
            return
        }
        if self.firmwareInfo.status.currentStatus == .Error {
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
        self.delegate?.refreshItem(InViewController: self, at: indexInPreviousTableView) {
            UIView.transition(with: self.customInfoTableView,
                              duration: 0.15,
                              options: .transitionCrossDissolve,
                              animations: { self.tableView.reloadData() })
        }
    }
}
@available(iOS 9.0, *)
extension CustomFirmwareInfoViewController {
    override var previewActionItems: [UIPreviewActionItem] {
        return [
            UIPreviewAction(title: "Refresh", style: .default, handler: { (_, previewViewController) in
                let pvc = (previewViewController as! CustomFirmwareInfoViewController)
                pvc.delegate?.refreshItem(InViewController: nil, at: pvc.indexInPreviousTableView, completionHandler: nil)
            }),
            UIPreviewAction(title: "Delete", style: .destructive, handler: { (_, previewViewController) in
                let pvc = (previewViewController as! CustomFirmwareInfoViewController)
                pvc.delegate?.deleteItem(at: pvc.indexInPreviousTableView)
            })
        ]
    }
}
extension CustomFirmwareInfoViewController : UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        self.delegate?.finishedLabelSetting(text: textField.text!, at: self.indexInPreviousTableView)
        return false
    }
}
