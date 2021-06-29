//
//  WebPageViewController.swift
//  MobileTSS
//
//  Created by User on 11/30/19.
//

import UIKit
import WebKit

class WebpageViewController: UIViewController {

    private let url = URL(string: "https://www.theiphonewiki.com/wiki/Beta_Firmware")!
    private var webView: WKWebView!
    var loadFirmwareActionBlock: ((String) -> Void)!

    override func loadView() {
        let webConfiguration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let myRequest = URLRequest(url: url)
        webView.load(myRequest)
        // Do any additional setup after loading the view.
    }

    @IBAction func refreshPage(_ sender: UIBarButtonItem) {
        if webView.url == nil {
            webView.load(URLRequest(url: url))
        }
        else {
            webView.reload()
        }
    }
    @IBAction private func cancelButtonTapped(_ sender: UIBarButtonItem) {
        dismiss(animated: true)
    }
}
extension WebpageViewController : WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let urlString = navigationAction.request.url?.absoluteString else {
            decisionHandler(.allow)
            return
        }
        // magic number 6 which should include file extension
        guard let substr = urlString.suffix(6).split(separator: ".").last else {
            decisionHandler(.allow)
            return
        }

        if substr == "ipsw" || substr == "zip" {
            let alert = UIAlertController(title: "Firmware Link Found", message: "Do you want to use \"\(urlString)\"", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "No", style: .cancel))
            alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { (_) in
                self.dismiss(animated: true, completion: {
                    self.loadFirmwareActionBlock(urlString)
                })
            }))
            present(alert, animated: true)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}
