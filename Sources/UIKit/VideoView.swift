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

class VideoView: UIView {
    
    let webView: WKWebView!
    
    init(frame: CGRect, videoProperties: VideoViewProperties) {
        
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        if #available(iOS 10.0, *) {
            config.mediaTypesRequiringUserActionForPlayback = .audio
        }
        self.webView = WKWebView(frame: frame,
                                 configuration: config)
        webView.scrollView.isScrollEnabled = false
        super.init(frame: frame)
        
        self.addSubview(webView)
        
        webView.alpha = 0
        webView.navigationDelegate = self
        
        let options: [String] = [
            videoProperties.controls ? "controls" : nil,
            videoProperties.autoplay ? "autoplay" : nil,
            videoProperties.loop ? "loop" : nil,
        ].compactMap({ $0 })
        
        let type: String = videoProperties.mime.flatMap { $0.count > 0 ? "type='\($0)'" : nil } ?? ""
        
        let htmlStr = """
<video style="position: absolute; top:0px; left:0px;" width="100%" height="100%" \(options.joined(separator: " ")) playsinline muted preload="metadata">
<source \(type) src="\(videoProperties.source.absoluteString)">
</video>
"""
        webView.loadHTMLString(htmlStr, baseURL: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
extension VideoView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        UIView.animate(withDuration: 0.2) {
            self.webView.alpha = 1
        }
    }
}
