//
//  FetchIntervalTableViewController.swift
//  MobileTSS
//
//  Created by User on 12/29/18.
//

import UIKit

class FetchIntervalTableViewController: UITableViewController {

    var selectedIndexCallback: ((Int) -> Void)!
    var currentSelectedIndex: Int = 0
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        if indexPath.row == self.currentSelectedIndex {
            cell.accessoryType = .checkmark
        }
        else {
            cell.accessoryType = .none
        }
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row != self.currentSelectedIndex else {
            return
        }
        let previous = IndexPath(row: self.currentSelectedIndex, section: 0)
        tableView.cellForRow(at: previous)!.accessoryType = .none
        let selectedCell = tableView.cellForRow(at: indexPath)!
        selectedCell.accessoryType = .checkmark
        tableView.deselectRow(at: indexPath, animated: true)
        self.currentSelectedIndex = indexPath.row
        self.selectedIndexCallback(self.currentSelectedIndex)
    }
}
