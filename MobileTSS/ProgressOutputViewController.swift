//
//  ProgressOutputViewController.swift
//  MobileTSS
//
//  Created by User on 7/18/18.
//

import UIKit

class ProgressOutputViewController: UIViewController {
    var configurationBlock: (() -> Void)?
    var actionAfterViewAppeared: (() -> Void)?
    var cancelBlock: (() -> Void)?
    
    @IBOutlet private weak var navigationBar: UINavigationBar!
    @IBOutlet private weak var dismissButton: UIBarButtonItem!
    @IBOutlet private weak var outputView: UITextView!

    var topTitle: String? {
        get {
            return navigationBar?.items?.first?.title
        }
        set {
            navigationBar?.items?.first?.title = newValue
        }
    }
    var backButtonTitle: String? {
        get {
            return dismissButton?.title
        }
        set {
            dismissButton?.title = newValue
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 13.0, *) {
            isModalInPresentation = true
        }
        configurationBlock?()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let actionAfterViewAppeared = actionAfterViewAppeared {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                self.dismissButton.isEnabled = true
                actionAfterViewAppeared()
                self.actionAfterViewAppeared = nil
            })
        }
        else {
            dismissButton.isEnabled = true
        }
    }
    func addTextToOutputView(_ text: String) {
        outputView.text = outputView.text + text + "\n"
        outputView.scrollRangeToVisible(NSMakeRange(outputView.text.count - 1, 1))
    }
    @IBAction private func dismissCurrentViewController(_ sender: UIBarButtonItem) {
        cancelBlock?()
        cancelBlock = nil
        dismiss(animated: true)
    }
}
extension ProgressOutputViewController : UIBarPositioningDelegate {
    func position(for bar: UIBarPositioning) -> UIBarPosition {
        return .topAttached
    }
}
