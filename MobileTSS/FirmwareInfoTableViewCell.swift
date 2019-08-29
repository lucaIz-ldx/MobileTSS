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

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.cellInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.cellInit()
    }
    private func createContentLabel() {
        let rvalueViewFrame = CGRect(x: intervalBetweenViewsAndSideBorder + widthForIdentifierLabel + intervalBetweenIdentifierLabelAndContentLabel, y: intervalBetweenViewsAndTopBottomBorder, width: self.bounds.size.width - (intervalBetweenViewsAndSideBorder * 2 + widthForIdentifierLabel + intervalBetweenIdentifierLabelAndContentLabel), height: self.identifierLabel.bounds.size.height)
        let contentLabel = UILabel(frame: rvalueViewFrame)

        contentLabel.adjustsFontSizeToFitWidth = true
        contentLabel.minimumScaleFactor = 9/contentLabel.font.pointSize
        contentLabel.autoresizingMask = [.flexibleWidth, .flexibleLeftMargin]

        contentLabel.font = UIFont.systemFont(ofSize: 17)

        contentLabel.textAlignment = .center
        self.contentView.addSubview(contentLabel)
        self.contentLabel = contentLabel
    }

    var rvalueEditable: Bool {
        get {
            return self.contentTextField != nil
        }
        set {
            // if an actual change is made.
            guard self.rvalueEditable != newValue else {return}
            let rvalueViewFrame = CGRect(x: intervalBetweenViewsAndSideBorder + widthForIdentifierLabel + intervalBetweenIdentifierLabelAndContentLabel, y: intervalBetweenViewsAndTopBottomBorder, width: self.bounds.size.width - (intervalBetweenViewsAndSideBorder * 2 + widthForIdentifierLabel + intervalBetweenIdentifierLabelAndContentLabel), height: self.identifierLabel.bounds.size.height)
            if newValue {
                let currentContent = self.contentLabel?.text ?? ""
                self.contentLabel?.removeFromSuperview()
                self.contentLabel = nil
                let _contentTextField = UITextField(frame: rvalueViewFrame)
                _contentTextField.text = currentContent
                _contentTextField.autoresizingMask = [.flexibleWidth, .flexibleLeftMargin]
                _contentTextField.autocapitalizationType = .none
                _contentTextField.keyboardType = .asciiCapable
                _contentTextField.textAlignment = .center
                _contentTextField.returnKeyType = .done
                self.contentTextField = _contentTextField
                self.contentView.addSubview(_contentTextField)
            }
            else {
                self.contentTextField?.removeFromSuperview()
                self.contentTextField = nil
//                createContentLabel(rvalueViewFrame)
            }
        }
    }
    var identifierText: String? {
        get {
            return self.identifierLabel.text
        }
        set {
            self.identifierLabel?.text = newValue
        }
    }
    var contentText: String? {
        get {
            return self.contentLabel == nil ? self.contentTextField?.text : self.contentLabel?.text
        }
        set {
            self.contentLabel?.text = newValue
            self.contentTextField?.text = newValue
        }
    }

    private let intervalBetweenViewsAndSideBorder: CGFloat = 15
    private let intervalBetweenViewsAndTopBottomBorder: CGFloat = 10
    private let widthForIdentifierLabel: CGFloat = 120
    private let intervalBetweenIdentifierLabelAndContentLabel: CGFloat = 20

    private func cellInit() {
        self.identifierLabel = UILabel(frame: CGRect(x: intervalBetweenViewsAndSideBorder, y: intervalBetweenViewsAndTopBottomBorder, width: widthForIdentifierLabel, height: self.bounds.size.height - 2 * intervalBetweenViewsAndTopBottomBorder))
        self.identifierLabel.adjustsFontSizeToFitWidth = true
        self.identifierLabel.minimumScaleFactor = 12/self.identifierLabel.font.pointSize
//        self.identifierLabel.font = UIFont.systemFont(ofSize: 17)
//        self.identifierLabel.textAlignment = .center
        self.identifierLabel.autoresizingMask = [.flexibleWidth, .flexibleRightMargin]

        self.contentView.addSubview(self.identifierLabel)
        self.createContentLabel()
    }
}
