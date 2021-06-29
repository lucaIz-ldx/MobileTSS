//
//  ScrollableLabelTableViewCell.swift
//  MobileTSS
//
//  Created by User on 1/18/19.
//

import UIKit

class ScrollableLabelTableViewCell: UITableViewCell {
    @IBOutlet private weak var leftSideLabel: UILabel!
    @IBOutlet private(set) weak var scrollView: UIScrollView!
    private lazy var contentLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .right
        scrollView.addSubview(label)
        return label
    }()
    var leftSideText: String? {
        get {
            return leftSideLabel.text
        }
        set {
            leftSideLabel.text = newValue
        }
    }
    var rightSideScrollableText: String? {
        get {
            return contentLabel.text
        }
        set {
            contentLabel.text = newValue
            contentLabel.sizeToFit()
        }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        // force scrollView to reset frame
        scrollView.setNeedsLayout()
        scrollView.layoutIfNeeded()

        // keep the height same as scrollView
        contentLabel.bounds.size.height = scrollView.bounds.size.height
        let widthDiff = scrollView.bounds.size.width - contentLabel.bounds.size.width
        if widthDiff > 0 {
            contentLabel.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin]
            contentLabel.frame.origin.x = widthDiff
        }
        else {
            contentLabel.autoresizingMask = []
            contentLabel.frame.origin.x = 0
        }
        contentLabel.frame.origin.y = 0
        scrollView.contentSize = contentLabel.bounds.size
    }
}
