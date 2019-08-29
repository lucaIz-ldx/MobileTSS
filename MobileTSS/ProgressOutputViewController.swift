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
            return self.navigationBar?.items?.first?.title
        }
        set {
            self.navigationBar?.items?.first?.title = newValue
        }
    }
    var backButtonTitle: String? {
        get {
            return self.dismissButton?.title
        }
        set {
            self.dismissButton?.title = newValue
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.configurationBlock?()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let actionAfterViewAppeared = self.actionAfterViewAppeared {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                self.dismissButton.isEnabled = true
                actionAfterViewAppeared()
            })
        }
        else {
            self.dismissButton.isEnabled = true
        }
    }
    func addTextToOutputView(_ text: String) {
        self.outputView.text = self.outputView.text + text + "\n"
        self.outputView.scrollRangeToVisible(NSMakeRange(self.outputView.text.count - 1, 1))
    }
    @IBAction private func dismissCurrentViewController(_ sender: UIBarButtonItem) {
        cancelBlock?()
        cancelBlock = nil
        self.dismiss(animated: true)
    }
}
extension ProgressOutputViewController : UIBarPositioningDelegate {
    func position(for bar: UIBarPositioning) -> UIBarPosition {
        return .topAttached
    }
}
