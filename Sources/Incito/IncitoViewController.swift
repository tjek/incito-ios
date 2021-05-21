///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

import UIKit
import WebKit

public protocol IncitoViewControllerDelegate: class {
    
    /// Called once the a document is successfully loaded.
    func incitoDocumentLoaded(document: IncitoDocument, in viewController: IncitoViewController)
    
    /// Called when all the view elements have finished being positioned on screen.
    func incitoFinishedRendering(in viewController: IncitoViewController)
    
    /// Called whenever the user scrolls the incito (or the incito is scrolled programatically).
    func incitoDidScroll(progress: Double, in viewController: IncitoViewController)
    
    /// Called whenever the user ends dragging the incito
    func incitoWillEndDragging(withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>, in viewController: IncitoViewController)
    
    /// Called when the user taps a location within the incito. The point is in the coordinate space of the `viewController`'s `view`. This will not be called if the tap is on a link.
    func incitoDidReceiveTap(at point: CGPoint, in viewController: IncitoViewController)
    
    /// Called when the user long presses a location within the incito. The point is in the coordinate space of the `viewController`'s `view`. This will not be called if the tap is on a link.
    func incitoDidReceiveLongPress(at point: CGPoint, in viewController: IncitoViewController)
    
    /// Called when the user taps a link. The general `incitoDidReceiveTap` delegate method is not called if a link was tapped. If you do not implement this delegate method, the default behaviour is to simply open the url in Safari.
    func incitoDidTapLink(_ url: URL, in viewController: IncitoViewController)
}

/// Default delegate method implementations
public extension IncitoViewControllerDelegate {
    
    func incitoDocumentLoaded(document: IncitoDocument, in viewController: IncitoViewController) { }
    
    func incitoFinishedRendering(in viewController: IncitoViewController) { }
    
    func incitoDidScroll(progress: Double, in viewController: IncitoViewController) { }
    
    func incitoWillEndDragging(withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>, in viewController: IncitoViewController) { }
    
    func incitoDidReceiveTap(at point: CGPoint, in viewController: IncitoViewController) { }
    
    func incitoDidReceiveLongPress(at point: CGPoint, in viewController: IncitoViewController) { }
    
    /// Default to opening the url when tapping a link.
    func incitoDidTapLink(_ url: URL, in viewController: IncitoViewController) {
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            UIApplication.shared.openURL(url)
        }
    }
}

/**
 A view controller for rendering an incito.
 */
public class IncitoViewController: UIViewController {
    
    enum LoadError: Error {
        case unableToLoadHTMLString
    }
    
    public static func load(document: (IncitoDocument), delegate: IncitoViewControllerDelegate? = nil, completion: @escaping (Result<IncitoViewController, Error>) -> Void) {
        var vc: IncitoViewController? = nil
        vc = IncitoViewController(document: document) {
            if let err = $0 {
                completion(.failure(err))
            } else {
                completion(.success(vc!))
            }
            vc = nil
        }
        vc?.delegate = delegate
    }
    
    // MARK: Public vars
    
    public weak var delegate: IncitoViewControllerDelegate?

    /// 0-1 percentage of the screen that we are currently scrolled to. Can be <0 or >1 when over-scrolling.
    /// Note: this value will not be accurate until `incitoFinishedRendering` delegate method is called.
    public var scrollProgress: Double {
        return scrollView.percentageProgress
    }
    
    /// Value representing how many px has the incito been scrolled from the top.
    public var scrollPosition: CGFloat {
        return scrollView.contentOffset.y
    }
    
    public let incitoDocument: IncitoDocument

    public fileprivate(set) var tapGesture: UITapGestureRecognizer!
    public fileprivate(set) var longPressGesture: UILongPressGestureRecognizer!
    
    /**
     When loading an incito, should we first try to use the incito renderer hosted at a remote cdn, before using the locally hosted renderer.
     */
    public static var useRemoteRendererHTML: Bool = true
    
    // MARK: Private vars
    
    fileprivate static let localHTMLFileName = "index-1.0.0.html"
    fileprivate static let remoteHTMLFileURL = URL(string: "https://incito-webview.shopgun.com/index-1.0.0.html")!
    
    fileprivate class DefaultDelegate: IncitoViewControllerDelegate { }
    fileprivate var delegateOrDefault: IncitoViewControllerDelegate {
        return self.delegate ?? DefaultDelegate()
    }
    
    fileprivate let loadCompletion: (Error?) -> Void
    
    fileprivate var scrollView: UIScrollView {
        return webView.scrollView
    }
    
    fileprivate var scrollViewScrollObserver: NSKeyValueObservation?

    fileprivate lazy var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true

        let contentController = WKUserContentController()
        
        // add event listeners
        contentController.add(self, name: "incitoFinishedRendering")
        
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        return webView
    }()
    
    // MARK: Public funcs
    
    public init(document: IncitoDocument, completion: @escaping (Error?) -> Void) {
        self.incitoDocument = document
        self.loadCompletion = completion
        
        super.init(nibName: nil, bundle: nil)
                
        IncitoViewController.loadWebViewHTML { [weak self] in
            guard let htmlStr = $0 else {
                self?.loadCompletion(LoadError.unableToLoadHTMLString)
                return
            }
            self?.webView.loadHTMLString(htmlStr, baseURL: nil)
        }
        
        // remove the old cache from previous cache lib, if it exists
        if let legacyCacheFolderURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("com.shopgun.incito.cache.v1") {
            try? FileManager.default.removeItem(at: legacyCacheFolderURL)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = incitoDocument.backgroundColor ?? .white
        
        self.webView.scrollView.delegate = self
        
        // Add the WebView to the root
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        // observe changes to the contentOffset, and trigger a re-render if needed.
        // we do this, rather than acting as delegate, as the users of the library may want to be the scrollview's delegate.
        scrollViewScrollObserver = scrollView.observe(\.contentOffset, options: [.old, .new]) { [weak self] (_, change) in
            guard let self = self, change.oldValue != change.newValue, self.scrollView.contentSize.height > 0 else { return }
            
            self.delegate?.incitoDidScroll(progress: self.scrollProgress, in: self)
        }
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapView))
        self.tapGesture = tap
        self.addGesture(tap)
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPressView))
        self.longPressGesture = longPress
        self.addGesture(longPress)
    }
    
    deinit {
        scrollViewScrollObserver = nil
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // in < iOS 11.0 contentInset must be updated manually
        if #available(iOS 11.0, *) { } else {
            if self.automaticallyAdjustsScrollViewInsets {
                scrollView.contentInset = UIEdgeInsets(top: self.topLayoutGuide.length,
                                                       left: 0.0,
                                                       bottom: self.bottomLayoutGuide.length,
                                                       right: 0.0)
                scrollView.scrollIndicatorInsets = scrollView.contentInset
            }
        }
    }
    
    /**
     Add a gesture recognizer to the incito view.
     
     Note: this assigns the `delegate` of the gesture.
     We do this because the underlying renderer needs to be able to accept gestures simultaneously.
     */
    public func addGesture(_ gesture: UIGestureRecognizer) {
        gesture.delegate = self
        self.view.addGestureRecognizer(gesture)
    }
    
    // MARK: - Private funcs
    
    /**
     Try to load the raw HTML string for the incito webview.
     First tries to load from the CDN, and if that fails, loads from the local file, and IF that fails we are in trouble.
     Done on a background queue. Completes on the main queue.
     */
    fileprivate static func loadWebViewHTML(completion: @escaping (String?) -> Void) {
        DispatchQueue.global().async {
            var fallbackHtmlStr: String? {
                guard let localURL = Bundle.incito.url(forResource: localHTMLFileName, withExtension: nil) else {
                    return nil
                }
                return try? String(contentsOf: localURL)
            }
            
            let htmlStr: String? = useRemoteRendererHTML ? (try? String(contentsOf: remoteHTMLFileURL)) ?? fallbackHtmlStr : fallbackHtmlStr
            DispatchQueue.main.async {
                completion(htmlStr)
            }
        }
    }
    
    fileprivate func loadIncito() {
        webView.evaluateJavaScript("window.init(\(incitoDocument.json))") { [weak self] (_, error) in
            guard let self = self else { return }

            if let error = error {
                self.loadCompletion(error)
            } else {
                self.loadCompletion(nil)
                self.delegate?.incitoDocumentLoaded(document: self.incitoDocument, in: self)
            }
        }
    }
    
    @objc fileprivate func didTapView(_ tap: UITapGestureRecognizer) {
        let location = tap.location(in: self.view)
        delegate?.incitoDidReceiveTap(at: location, in: self)
    }
    
    @objc fileprivate func didLongPressView(_ tap: UITapGestureRecognizer) {
        let location = tap.location(in: self.view)
        guard longPressGesture.state == .began else { return }
        delegate?.incitoDidReceiveLongPress(at: location, in: self)
    }
}

extension IncitoViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // only accept simultaneous gestures if they are on the webview
        // walk up the otherGesture's view hierarchy to see if any of it's parents are a WKWebView. Eject if we hit the root view of this VC.
        var view = otherGestureRecognizer.view
        while view != nil {
            if view is WKWebView {
                return true
            } else if view == self.view {
                return false
            }
            view = view?.superview
        }

        return false
    }
}

extension IncitoViewController: WKNavigationDelegate, WKUIDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadIncito()
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadCompletion(error)
    }
    
    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            delegateOrDefault.incitoDidTapLink(url, in: self)
        }
        return nil
    }
}

extension IncitoViewController: WKScriptMessageHandler {
    
    /// Catch events from javascript, and convert them into delegate messages.
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "incitoFinishedRendering" {
            
            // if we get a height back, assign that to the contentSize to make sure it is accurate before the delegate method gets called.
            if let height = message.body as? CGFloat, height > 0 {
                self.scrollView.contentSize.height = height
            }
            
            // dispatch on main to make sure that the contentSize change is registered
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.incitoFinishedRendering(in: self)
            }
        }
    }
}



// MARK: - Accessors

extension IncitoViewController {
    
    /**
     Returns an array of the elements at the specified point.
     `point` must be in the `IncitoViewController`'s root `view` coordinate space.
     `completion` is called on the main queue.
     */
    public func getElements(at point: CGPoint, completion: @escaping ([IncitoDocument.Element]) -> Void) {
        
        let inset: UIEdgeInsets
        if #available(iOS 11.0, *) {
            inset = self.scrollView.adjustedContentInset
        } else {
            inset = self.scrollView.contentInset
        }
        
        var pointInWebView = self.view.convert(point, to: self.webView)
        pointInWebView.x -= inset.left
        pointInWebView.y -= inset.top
        
        let elementsAtJS = "getElementIdsAtPoint(\(pointInWebView.x), \(pointInWebView.y))"
        
        webView.evaluateJavaScript(elementsAtJS) { [weak self] (res, err) in
            guard let self = self else { return }
            
            let matchedElements: [IncitoDocument.Element] = (res as? [String])
                .flatMap({ matchedIds in
                    self.incitoDocument.elements.filter({
                        matchedIds.contains($0.id)
                    })
                }) ?? []
            
            completion(matchedElements)
        }
    }
    
    public func getFirstElement(at point: CGPoint, where predicate: @escaping (IncitoDocument.Element) -> Bool, completion: @escaping (IncitoDocument.Element?) -> Void) {
        self.getElements(at: point) {
            completion($0.first(where: predicate))
        }
    }
    
    /**
     Returns the bounds of element with the specified id, in the coordinate space of the root `view`.
     `completion` is called on the main queue.
     */
    public func getBoundsOfElement(withId elementId: IncitoDocument.Element.Identifier, completion: @escaping (CGRect?) -> Void) {
        
        let boundsOfElJS = "absoluteBoundsOfElementWithId('\(elementId)')"
        
        webView.evaluateJavaScript(boundsOfElJS) { [weak self] (res, err) in
            guard let self = self else { return }
            
            let rect: CGRect? = (res as? [String: Double]).flatMap({
                guard
                    let top = $0["top"],
                    let left = $0["left"],
                    let width = $0["width"],
                    let height = $0["height"]
                    else { return nil }
                return CGRect(x: left, y: top, width: width, height: height)
            })
            
            let rectInView = rect.map({ self.scrollView.convert($0, to: self.view) })
            completion(rectInView)
        }
    }
}

// MARK: - Scrolling

extension IncitoViewController: UIScrollViewDelegate {
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        tapGesture.isEnabled = false
        longPressGesture.isEnabled = false
    }
    
    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        tapGesture.isEnabled = true
        longPressGesture.isEnabled = true
        self.delegate?.incitoWillEndDragging(withVelocity: velocity, targetContentOffset: targetContentOffset, in: self)
    }
    
}

extension IncitoViewController {

    /**
     Provides an opportunity to configure the scrollView used by the incito. It is possible to assign yourself as the delegate of the scrollView, if you need.
     - parameter configurator: A callback that is passed the scrollview used by the incito. You can perform any configurations of the scrollview in here.
     */
    public func configureScrollView(_ configurator: (UIScrollView) -> Void) {
        let scrollView = self.scrollView
        configurator(scrollView)
    }
    
    /**
     An enum that defines how you wish to position an element when scrolling to it.
     */
    public enum ScrollPosition {
        /// The element is at the top of the screen.
        case top
        /// The element is centered vertically within the screen.
        case centeredVertically
        /// The element is centered vertically within the screen, but the screen has additional top & bottom margins
        case centeredVerticallyWithin(topMargin: CGFloat, bottomMargin: CGFloat)
        /// The element is at the bottom of the screen.
        case bottom
    }
    
    /**
     Scrolls the incito to show the element with the specified id. If the element doesnt exist this is a no-op. See parameters for different ways of positioning the scroll.

     - parameter elementId: The id of the element to scroll to.
     - parameter position: Where within the screen the element should be positioned. Defaults to `.top`.
     - parameter useContentInsets: Whether the position is relative to the scrollView's adjustedContentInsets. If false the top/bottom of the scroll view is used. Defaults to `true`.
     - parameter extraOffset: Scrolls further down by this amount. Defaults to `0`.
     - parameter clampOffset: If true it clamps the offset so that we do not scroll further than you could by dragging. Defaults to `true`.
     - parameter keepTopVisible: If true it stops the top of the specified element going above the top of the visible area (taking into account the `useContentInsets` parameter). This can happen if the element's bounds are larger than the visible area. Defaults to `true`.
     - parameter animated: If true the scrolling to the element will be animated.
     */
    public func scrollToElement(
        withId elementId: IncitoDocument.Element.Identifier,
        position: ScrollPosition = .top,
        useContentInsets: Bool = true,
        extraOffset: CGFloat = 0,
        clampOffset: Bool = true,
        keepTopVisible: Bool = true,
        animated: Bool
    ) {

        self.getBoundsOfElement(withId: elementId) { [weak self] in
            guard let self = self else { return }
            guard let bounds = $0 else { return }
            
            // the element's rect within the scrollview
            let scrollRect =  self.view.convert(bounds, to: self.scrollView)
            
            let inset: UIEdgeInsets = {
                if #available(iOS 11.0, *) {
                    return self.scrollView.adjustedContentInset
                } else {
                    return self.scrollView.contentInset
                }
            }()
            
            var offsetY = scrollRect.origin.y
            offsetY -= extraOffset
            
            switch position {
            case .top:
                if useContentInsets {
                    offsetY -= inset.top
                }
            case .centeredVertically:
                if useContentInsets {
                    offsetY -= (inset.top - inset.bottom)/2
                }
                offsetY -= (self.scrollView.frame.size.height) / 2
                offsetY += (scrollRect.size.height / 2)
            case .bottom:
                if useContentInsets {
                    offsetY += inset.bottom
                }
                offsetY -= (self.scrollView.frame.size.height)
                offsetY += scrollRect.size.height
            case let .centeredVerticallyWithin(topMargin, bottomMargin):
                if useContentInsets {
                    offsetY -= (inset.top - inset.bottom)/2
                }
                
                offsetY -= (topMargin - bottomMargin)/2
                offsetY -= (self.scrollView.frame.size.height) / 2
                offsetY += (scrollRect.size.height / 2)
            }
            
            if keepTopVisible {
                var topLimit = scrollRect.origin.y
                if useContentInsets {
                    topLimit -= inset.top
                }
                
                offsetY = min(offsetY, topLimit)
            }
            
            if clampOffset {
                offsetY = Swift.min(Swift.max(offsetY, -inset.top), self.scrollView.contentSize.height - self.scrollView.frame.size.height + inset.bottom)
            }
            
            self.scrollView.setContentOffset(CGPoint(x: 0, y: offsetY), animated: animated)
        }
    }

    /**
     Scrolls the incito to the specified % progress (a value from 0-1).
     - parameter progress: A value of 0-1 defining what % of the incito to scroll to (0 being top, 1 being bottom)
     - parameter animated: If true the scrolling to position will be animated.
     */
    public func scrollToProgress(_ progress: Double, animated: Bool) {
        let contentOffset = self.scrollView.contentOffset(forPercentageProgress: progress)

        self.scrollView.setContentOffset(contentOffset, animated: animated)
    }
    
    /**
     Scrolls the incito to the specified offset.
     - parameter position: A value defining how many px to scroll the incito.
     - parameter animated: If true the scrolling to position will be animated.
     */
    public func scrollToPosition(_ position: CGFloat, animated: Bool) {
        let scrollPosition = CGPoint(x: 0, y: position)
        
        self.scrollView.setContentOffset(scrollPosition, animated: animated)
    }
}

// MARK: - Utilities

extension UIScrollView {
    var percentageProgress: Double {
        let adjustedInset: UIEdgeInsets
        if #available(iOS 11.0, *) {
            adjustedInset = self.adjustedContentInset
        } else {
            adjustedInset = self.contentInset
        }
        let totalHeight = self.contentSize.height + adjustedInset.top + adjustedInset.bottom - bounds.size.height
        guard totalHeight > 0 else { return 0 }
        
        let topOffset = self.contentOffset.y + adjustedInset.top
        
        return Double(topOffset / totalHeight)
    }
    
    func contentOffset(forPercentageProgress progress: Double) -> CGPoint {
        
        let adjustedInset: UIEdgeInsets
        if #available(iOS 11.0, *) {
            adjustedInset = self.adjustedContentInset
        } else {
            adjustedInset = self.contentInset
        }
        
        let totalHeight = self.contentSize.height + adjustedInset.top + adjustedInset.bottom - bounds.size.height
        
        let topOffset = CGFloat(progress) * totalHeight
        
        let offsetY = topOffset - adjustedInset.top
        
        return CGPoint(x: 0, y: offsetY)
    }
}
