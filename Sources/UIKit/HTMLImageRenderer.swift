//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2019 ShopGun. All rights reserved.

import UIKit
import WebKit

protocol HTMLImageRenderer {
    func render(_ htmlStr: String, containerSize: CGSize, baseURL: URL?) -> UIImage?
}

var SharedHTMLImageRenderer: HTMLImageRenderer {
    if #available(iOS 11.0, *) {
        return WebKitHTMLImageRenderer.shared
    } else {
        return UIKitHTMLImageRenderer.shared
    }
}

extension HTMLImageRenderer {
    /**
     Given some SVGData, this will try to return a snapshot of the SVG at the specified size.
     
     Note: This can be rather slow (up to 500ms, esp for the first SVG), so it should be performed on a BG queue
     */
    func renderSVG(_ svgData: Data, containerSize: CGSize, baseURL: URL?) -> UIImage? {
        
        guard containerSize.height > 0, containerSize.width > 0,
            let svgStr = String(data: svgData, encoding: .utf8) else {
                return nil
        }
        
        let htmlStr = "<div style='position: absolute;top: 0px;left: 0px;width: 100vw;height: 100vh;'>\(svgStr)</div>"
        
        return self.render(htmlStr, containerSize: containerSize, baseURL: baseURL)
    }
}

/**
 An HTML renderer, that syncronously renders an html string to a UIImage using a WKWebView.
 */
@available(iOS 11.0, *)
class WebKitHTMLImageRenderer: HTMLImageRenderer {
    
    static let shared = WebKitHTMLImageRenderer()
    
    var webView: WKWebView?
    let queue: DispatchQueue = DispatchQueue(label: "WebKitHTMLRenderQueue", qos: .userInitiated)
    let timeout: TimeInterval = 10
    
    func render(_ htmlStr: String, containerSize: CGSize, baseURL: URL? = nil) -> UIImage? {
        var image: UIImage? = nil
        queue.sync { [unowned self] in
            
            let grp = DispatchGroup()
            grp.enter()
            let delegate = WebViewRendererDelegate { imageSnap in
                image = imageSnap
                grp.leave()
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                if self.webView == nil {
                    self.webView = WKWebView(frame: .zero, configuration: {
                        let config = WKWebViewConfiguration()
                        config.preferences.javaScriptEnabled = false
                        return config
                    }())
                }
                
                let frame = CGRect(origin: .zero, size: containerSize)
                
                self.webView?.frame = frame
                self.webView?.navigationDelegate = delegate
                
                self.webView?.loadHTMLString(htmlStr, baseURL: baseURL)
            }
            
            _ = grp.wait(wallTimeout: .now() + self.timeout)
        }
        
        return image
    }
    
    class WebViewRendererDelegate: NSObject, WKNavigationDelegate {
        
        let completion: (UIImage?) -> Void
        init(completion: @escaping (UIImage?) -> Void) {
            self.completion = completion
        }
        
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            webView.backgroundColor = .clear
            webView.scrollView.backgroundColor = .clear
            webView.isOpaque = false
            webView.scrollView.isOpaque = false
            
            webView.takeSnapshot(with: nil) { (image, error) in
                self.completion(image)
            }
        }
    }
}

//MARK: - Legacy HTMLImageRenderer

/**
 As the 'snapshot' functionality of WKWebView is only available in iOS 11, this renderer using UIWebView should be used instead.
 */
class UIKitHTMLImageRenderer: HTMLImageRenderer {
    
    static let shared = UIKitHTMLImageRenderer()
    
    var webView: UIWebView?
    let queue: DispatchQueue = DispatchQueue(label: "UIKitHTMLRenderQueue", qos: .userInitiated)
    let timeout: TimeInterval = 10
    
    func render(_ htmlStr: String, containerSize: CGSize, baseURL: URL? = nil) -> UIImage? {
        
        var image: UIImage? = nil
        queue.sync { [unowned self] in
            
            let grp = DispatchGroup()
            grp.enter()
            let delegate = WebViewRendererDelegate { imageSnap in
                image = imageSnap
                grp.leave()
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                if self.webView == nil {
                    self.webView = UIWebView(frame: .zero)
                }
                
                let frame = CGRect(origin: .zero, size: containerSize)
                
                self.webView?.frame = frame
                self.webView?.delegate = delegate
                
                self.webView?.loadHTMLString(htmlStr, baseURL: baseURL)
            }
            
            _ = grp.wait(wallTimeout: .now() + self.timeout)
        }
        
        return image
    }
    
    class WebViewRendererDelegate: NSObject, UIWebViewDelegate {
        
        let completion: (UIImage?) -> Void
        init(completion: @escaping (UIImage?) -> Void) {
            self.completion = completion
        }
        func webViewDidFinishLoad(_ webView: UIWebView) {
            webView.backgroundColor = .clear
            webView.scrollView.backgroundColor = .clear
            webView.isOpaque = false
            webView.scrollView.isOpaque = false
            
            let image = webView.scrollView.snapshotAnImage()
            
            completion(image)
        }
    }
}

extension UIView {
    fileprivate func snapshotAnImage() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, self.isOpaque, 0.0)
        defer { UIGraphicsEndImageContext() }
        if let context = UIGraphicsGetCurrentContext() {
            self.layer.render(in: context)
            return UIGraphicsGetImageFromCurrentImageContext()
        }
        return nil
    }
}
