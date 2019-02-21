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
        
        let request = URLRequest(url: videoProperties.source)
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
}
