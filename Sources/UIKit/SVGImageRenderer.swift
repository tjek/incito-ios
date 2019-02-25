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

private let svgRenderQueue: DispatchQueue = DispatchQueue(label: "SVGRenderQueue", qos: .userInitiated)

private let sharedWebView = WKWebView(frame: .zero, configuration: {
    let config = WKWebViewConfiguration()
    config.preferences.javaScriptEnabled = false
    return config
}())

func renderSVG(svgData: Data, url: URL?, containerSize: CGSize) -> UIImage? {
    
    guard containerSize.height > 0, containerSize.width > 0,
        let svgStr = String(data: svgData, encoding: .utf8) else {
        return nil
    }
    var image: UIImage? = nil
    
    svgRenderQueue.sync {
        
        let grp = DispatchGroup()
        grp.enter()
        let delegate = SVGRendererWebKitDelegate(url: url!) { imageSnap in
            image = imageSnap
            grp.leave()
        }
        
        DispatchQueue.main.async {
            let frame = CGRect(origin: .zero, size: containerSize)
            
            let webView = sharedWebView
            webView.frame = frame
            webView.navigationDelegate = delegate
            
            let htmlStr = "<div style='position: absolute;top: 0px;left: 0px;width: 100vw;height: 100vh;'>\(svgStr)</div>"
            webView.loadHTMLString(htmlStr, baseURL: url)
        }
        
        _ = grp.wait(wallTimeout: .now() + 10)
    }
    return image
}

class SVGRendererWebKitDelegate: NSObject, WKNavigationDelegate, UIWebViewDelegate {
    
    let completion: (UIImage?) -> Void
    let url: URL
    init(url: URL, completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
        self.url = url
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.isOpaque = false
        
        if #available(iOS 11.0, *) {
            webView.takeSnapshot(with: nil) { (image, error) in
                self.completion(image)
            }
        }
    }
}
