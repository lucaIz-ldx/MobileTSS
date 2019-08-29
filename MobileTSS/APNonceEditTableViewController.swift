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
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveButtonTapped(_:)))

        if let apnonceText = self.apgenInfo[CustomAPGenKey.APNonce_Key] {
            do {
                try TSSRequest.parseNonce(in: apnonceText)
                self.apnonceTextField.text = apnonceText
            } catch _ {
                self.apgenInfo.removeValue(forKey: CustomAPGenKey.APNonce_Key)
            }
        }
        if let generatorText = self.apgenInfo[CustomAPGenKey.Generator_Key] {
            do {
                try TSSRequest.parseGenerator(in: generatorText)
                self.generatorTextField.text = generatorText
            } catch _ {
                self.apgenInfo.removeValue(forKey: CustomAPGenKey.Generator_Key)
            }
        }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if self.apgenInfo.isEmpty {
            self.apnonceTextField.becomeFirstResponder()
        }
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.finishEditingCallback(self.apgenInfo)
    }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 {
            return "The length of apnonce must be \(apNonceLengthForLocalDevice())."
        }
        return super.tableView(tableView, titleForFooterInSection: section)
    }
    override func numberOfSections(in tableView: UITableView) -> Int {
        if self.apgenInfo.isEmpty {
            return 2
        }
        return 3
    }

    @objc private func saveButtonTapped(_ sender: UIBarButtonItem) {
        // apnonce
        if let text = self.apnonceTextField.text, !text.isEmpty {
            do {
                try TSSRequest.parseNonce(in: text)
                self.apgenInfo[CustomAPGenKey.APNonce_Key] = text
            } catch let error {
                showErrorMessage(error.localizedDescription)
                return
            }
        }
        else {
            self.apgenInfo.removeValue(forKey: CustomAPGenKey.APNonce_Key)
        }
        // generator
        if let text = self.generatorTextField.text, !text.isEmpty {
            do {
                try TSSRequest.parseGenerator(in: text)
                self.apgenInfo[CustomAPGenKey.Generator_Key] = text
            } catch let error {
                showErrorMessage(error.localizedDescription)
                return
            }
        }
        else {
            self.apgenInfo.removeValue(forKey: CustomAPGenKey.Generator_Key)
        }
        self.navigationController?.popViewController(animated: true)
    }
    @IBAction func deleteButtonTapped(_ sender: UIButton) {
        self.apgenInfo.removeAll()
        self.navigationController?.popViewController(animated: true)
    }

    private func showErrorMessage(_ message: String) {
        let alertView = UIAlertController(title: LocalizedString.errorTitle, message: message, preferredStyle: .alert)
        alertView.addAction(UIAlertAction(title: "OK", style: .cancel))
        self.present(alertView, animated: true)
    }
}
extension APNonceEditTableViewController : UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}
extension String {
    subscript (i: Int) -> Character {
        return self[index(startIndex, offsetBy: i)]
    }
}
