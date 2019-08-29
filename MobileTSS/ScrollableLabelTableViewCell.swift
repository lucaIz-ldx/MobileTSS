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
        label.backgroundColor = .clear
        label.textAlignment = .right
        self.scrollView.addSubview(label)
        self.scrollView.layoutIfNeeded()
        return label
    }()
    var leftSideText: String? {
        get {
            return self.leftSideLabel.text
        }
        set {
            self.leftSideLabel.text = newValue
        }
    }
    var rightSideScrollableText: String? {
        get {
            return self.contentLabel.text
        }
        set {
            self.contentLabel.text = newValue
            self.setNeedsLayout()
        }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        self.contentLabel.sizeToFit()
        let size = self.contentLabel.bounds.size
        let adjustSize = CGSize(width: ceil(size.width) + 5, height: ceil(size.height))
        self.scrollView.layoutIfNeeded()
        self.contentLabel.frame.size = adjustSize
        self.contentLabel.frame.origin.y = (self.scrollView.bounds.size.height - adjustSize.height)/2
        if self.scrollView.bounds.contains(self.contentLabel.bounds) {
            self.contentLabel.frame.origin.x = self.scrollView.frame.size.width - adjustSize.width
            self.contentLabel.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin]
        }
        else {
            self.contentLabel.frame.origin.x = 0
            self.contentLabel.autoresizingMask = []
        }
        self.scrollView.contentSize = adjustSize
    }
}
