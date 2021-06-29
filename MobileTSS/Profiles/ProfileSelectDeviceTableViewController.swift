//
//  ProfileSelectDeviceTableViewController.swift
//  MobileTSS
//
//  Created by User on 12/6/19.
//

import UIKit

class ProfileSelectDeviceTableViewController: UITableViewController {

    var selectProfileBlock: ((DeviceProfile?) -> Void)!

    private var database: [String] = getAllKnownDeviceModels()

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return database.count
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "item", for: indexPath)
        cell.textLabel?.text = database[indexPath.row]
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedModel = database[indexPath.row]
        let array = findAllDeviceConfigurationsForSpecifiedModel(selectedModel)
        if array.count > 1 {
            let alert = UIAlertController(title: "Select boardconfig for \(selectedModel)", message: nil, preferredStyle: .alert)
            array.forEach { board in
                alert.addAction(UIAlertAction(title: board, style: .default, handler: { (_) in
                    self.selectProfileBlock(try! DeviceProfile(deviceModel: selectedModel, deviceBoard: board))
                    self.dismiss(animated: true)
                }))
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
                tableView.deselectRow(at: indexPath, animated: true)
            }))
            present(alert, animated: true)
        }
        else {
            selectProfileBlock(try! DeviceProfile(deviceModel: selectedModel, deviceBoard: array[0]))
        }
    }
    @IBAction private func cancelButtonTapped(_ sender: UIBarButtonItem) {
        selectProfileBlock(nil)
    }

}
