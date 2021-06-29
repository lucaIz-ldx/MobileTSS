//
//  FirmwareInfoTableViewCell.swift
//  MobileTSS
//
//  Created by User on 7/12/18.
//

import UIKit

class ButtonTableViewCell: UITableViewCell {
    @IBOutlet weak var button: UIButton!
}
class StatusLabelTableViewCell: UITableViewCell {
    @IBOutlet weak var label: UILabel!
}
class FirmwareInfoTableViewCell: UITableViewCell {

    private var identifierLabel: UILabel!
    private var contentLabel: UILabel?
    private(set) var contentTextField: UITextField?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        cellInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        cellInit()
    }
    private func createContentLabel() {
        let rvalueViewFrame = CGRect(x: intervalBetweenViewsAndSideBorder + widthForIdentifierLabel + intervalBetweenIdentifierLabelAndContentLabel, y: intervalBetweenViewsAndTopBottomBorder, width: bounds.size.width - (intervalBetweenViewsAndSideBorder * 2 + widthForIdentifierLabel + intervalBetweenIdentifierLabelAndContentLabel), height: identifierLabel.bounds.size.height)
        let contentLabel = UILabel(frame: rvalueViewFrame)

        contentLabel.adjustsFontSizeToFitWidth = true
        contentLabel.minimumScaleFactor = 9/contentLabel.font.pointSize
        contentLabel.autoresizingMask = [.flexibleWidth, .flexibleLeftMargin]

        contentLabel.font = UIFont.systemFont(ofSize: 17)

        contentLabel.textAlignment = .center
        contentView.addSubview(contentLabel)
        self.contentLabel = contentLabel
    }

    var rvalueEditable: Bool {
        get {
            return contentTextField != nil
        }
        set {
            // if an actual change is made.
            guard rvalueEditable != newValue else {return}
            let rvalueViewFrame = CGRect(x: intervalBetweenViewsAndSideBorder + widthForIdentifierLabel + intervalBetweenIdentifierLabelAndContentLabel, y: intervalBetweenViewsAndTopBottomBorder, width: bounds.size.width - (intervalBetweenViewsAndSideBorder * 2 + widthForIdentifierLabel + intervalBetweenIdentifierLabelAndContentLabel), height: identifierLabel.bounds.size.height)
            if newValue {
                let currentContent = contentLabel?.text ?? ""
                contentLabel?.removeFromSuperview()
                contentLabel = nil
                let _contentTextField = UITextField(frame: rvalueViewFrame)
                _contentTextField.text = currentContent
                _contentTextField.autoresizingMask = [.flexibleWidth, .flexibleLeftMargin]
                _contentTextField.autocapitalizationType = .none
                _contentTextField.keyboardType = .asciiCapable
                _contentTextField.textAlignment = .center
                _contentTextField.returnKeyType = .done
                contentTextField = _contentTextField
                contentView.addSubview(_contentTextField)
            }
            else {
                contentTextField?.removeFromSuperview()
                contentTextField = nil
//                createContentLabel(rvalueViewFrame)
            }
        }
    }
    var identifierText: String? {
        get {
            return identifierLabel.text
        }
        set {
            identifierLabel?.text = newValue
        }
    }
    var contentText: String? {
        get {
            return contentLabel == nil ? contentTextField?.text : contentLabel?.text
        }
        set {
            contentLabel?.text = newValue
            contentTextField?.text = newValue
        }
    }

    private let intervalBetweenViewsAndSideBorder: CGFloat = 15
    private let intervalBetweenViewsAndTopBottomBorder: CGFloat = 10
    private let widthForIdentifierLabel: CGFloat = 120
    private let intervalBetweenIdentifierLabelAndContentLabel: CGFloat = 20

    private func cellInit() {
        identifierLabel = UILabel(frame: CGRect(x: intervalBetweenViewsAndSideBorder, y: intervalBetweenViewsAndTopBottomBorder, width: widthForIdentifierLabel, height: bounds.size.height - 2 * intervalBetweenViewsAndTopBottomBorder))
        identifierLabel.adjustsFontSizeToFitWidth = true
        identifierLabel.minimumScaleFactor = 12/identifierLabel.font.pointSize
//        identifierLabel.font = UIFont.systemFont(ofSize: 17)
//        identifierLabel.textAlignment = .center
        identifierLabel.autoresizingMask = [.flexibleWidth, .flexibleRightMargin]

        contentView.addSubview(identifierLabel)
        createContentLabel()
    }
}
