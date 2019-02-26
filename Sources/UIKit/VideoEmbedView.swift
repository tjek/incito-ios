//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit
import WebKit

class VideoEmbedView: UIView {
    
    let webView: WKWebView!
    var didTapURL: ((URL) -> Void)?    
    
    init(frame: CGRect, videoProperties: VideoEmbedViewProperties) {
        
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        
        self.webView = WKWebView(frame: frame,
                                 configuration: config)
        webView.scrollView.isScrollEnabled = false
        super.init(frame: frame)
        
        self.addSubview(webView)
        
        webView.alpha = 0
        webView.navigationDelegate = self
        
        var targetURL = videoProperties.source
        
        // add "playsinline=1" as a query parameter
        if var urlComponents = URLComponents(url: targetURL, resolvingAgainstBaseURL: false) {
            var queryItems = urlComponents.queryItems ?? []
            queryItems += [
                URLQueryItem(name: "playsinline", value: "1")
            ]
            urlComponents.queryItems = queryItems
            if let tweakedURL = urlComponents.url(relativeTo: nil) {
                targetURL = tweakedURL
            }
        }

        let request = URLRequest(url: targetURL)
        webView.load(request)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
extension VideoEmbedView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        UIView.animate(withDuration: 0.2) {
            self.webView.alpha = 1
        }
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated,
            navigationAction.targetFrame == nil,
            let url = navigationAction.request.url {
            self.didTapURL?(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
}
