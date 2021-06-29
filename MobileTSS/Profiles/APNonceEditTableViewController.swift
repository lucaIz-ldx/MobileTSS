//
//  APNonceEditTableViewController.swift
//  MobileTSS
//
//  Created by User on 4/5/19.
//

import UIKit

class APNonceEditTableViewController: UITableViewController {

    @IBOutlet private weak var apnonceTextField: UITextField!
    @IBOutlet private weak var generatorTextField: UITextField!

    var apgenInfo: [String : String]!
    var finishEditingCallback: (([String : String]) -> Void)!

    private let deviceModel = PreferencesManager.shared.preferredProfile.deviceModel

    override func viewDidLoad() {
        super.viewDidLoad()
        if let apnonceText = apgenInfo[CustomAPGenKey.APNonce_Key] {
            do {
                try TSSAPNonce.parseAPNonce(apnonceText, deviceModel: deviceModel)
                apnonceTextField.text = apnonceText
            } catch _ {
                apgenInfo.removeValue(forKey: CustomAPGenKey.APNonce_Key)
            }
        }
        if let generatorText = apgenInfo[CustomAPGenKey.Generator_Key] {
            do {
                try TSSGenerator.parseGenerator(generatorText)
                generatorTextField.text = generatorText
            } catch _ {
                apgenInfo.removeValue(forKey: CustomAPGenKey.Generator_Key)
            }
        }
        if apgenInfo.isEmpty {
            title = "Add Info"
        }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if apgenInfo.isEmpty {
            apnonceTextField.becomeFirstResponder()
        }
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        finishEditingCallback(apgenInfo)
    }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 {
            return "The length of apnonce must be \(TSSAPNonce.requiredAPNonceLength(forDeviceModel: deviceModel))."
        }
        return super.tableView(tableView, titleForFooterInSection: section)
    }
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    @IBAction private func saveButtonTapped(_ sender: UIBarButtonItem) {
        // apnonce
        if let text = apnonceTextField.text, !text.isEmpty {
            do {
                try TSSAPNonce.parseAPNonce(text, deviceModel: deviceModel)
                apgenInfo[CustomAPGenKey.APNonce_Key] = text
            } catch let error {
                showErrorMessage(error.localizedDescription)
                return
            }
        }
        else {
            apgenInfo.removeValue(forKey: CustomAPGenKey.APNonce_Key)
        }
        // generator
        if let text = generatorTextField.text, !text.isEmpty {
            do {
                try TSSGenerator.parseGenerator(text)
                apgenInfo[CustomAPGenKey.Generator_Key] = text
            } catch let error {
                showErrorMessage(error.localizedDescription)
                return
            }
        }
        else {
            apgenInfo.removeValue(forKey: CustomAPGenKey.Generator_Key)
        }
        navigationController?.popViewController(animated: true)
    }

    private func showErrorMessage(_ message: String) {
        let alertView = UIAlertController(title: LocalizedString.errorTitle, message: message, preferredStyle: .alert)
        alertView.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alertView, animated: true)
    }
}
extension APNonceEditTableViewController : UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}
