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

public struct IncitoDocument: Identifiable {
    
    public struct Element {
        public var id: String
        public var role: String?
        public var meta: [String: JSONValue] = [:]
        public var featureLabels: [String] = []
        public var link: URL?
        public var title: String?
//        public var accessibility: String?
    }
    
    public var id: String
    public var version: String
    public var backgroundColor: UIColor? = nil
    public var meta: [String: JSONValue] = [:]
    public var locale: String?
    public var elements: [Element] = []
    
    public var json: String
}

public protocol IncitoViewControllerDelegate: class {
    
    /// Called whenever a document is updated.
    func incitoDocumentLoaded(in viewController: IncitoViewController)
    
    /// Called whenever the user scrolls the incito (or the incito is scrolled programatically).
    func incitoDidScroll(progress: Double, in viewController: IncitoViewController)
    
    /// Called when the user taps a location within the incito. The point is in the coordinate space of the `viewController`'s `view`. This will not be called if the tap is on a link.
    func incitoDidReceiveTap(at point: CGPoint, in viewController: IncitoViewController)
    
    /// Called when the user taps a link. The general `incitoDidReceiveTap` delegate method is not called if a link was tapped. If you do not implement this delegate method, the default behaviour is to simply open the url in Safari.
    func incitoDidTapLink(_ url: URL, in viewController: IncitoViewController)
}

/// Default delegate method implementations
public extension IncitoViewControllerDelegate {
    
    func incitoDocumentLoaded(in viewController: IncitoViewController) { }
    
    func incitoDidScroll(progress: Double, in viewController: IncitoViewController) { }
    
    func incitoDidReceiveTap(at point: CGPoint, in viewController: IncitoViewController) { }
    
    /// Default to opening the url when tapping a link.
    func incitoDidTapLink(_ url: URL, in viewController: IncitoViewController) {
        UIApplication.shared.openURL(url)
    }
}

/**
 A view controller for rendering an incito.
 */
public class IncitoViewController: UIViewController {
    
    // MARK: Public vars
    
    public weak var delegate: IncitoViewControllerDelegate?

    /// 0-1 percentage of the screen that we are currently scrolled to. Can be <0 or >1 when over-scrolling.
    public var scrollProgress: Double {
        return scrollView.percentageProgress
    }
    
    public private(set) var incitoDocument: IncitoDocument?
    
    // MARK: Private vars
    
    fileprivate class DefaultDelegate: IncitoViewControllerDelegate { }
    fileprivate var delegateOrDefault: IncitoViewControllerDelegate {
        return self.delegate ?? DefaultDelegate()
    }
    
    fileprivate var scrollView: UIScrollView {
        return webView.scrollView
    }
    
    fileprivate var scrollViewScrollObserver: NSKeyValueObservation?

    fileprivate lazy var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        
        webView.navigationDelegate = self
        webView.uiDelegate = self
        return webView
    }()
    
    // MARK: Public funcs
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add the WebView to the root
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        let htmlFileURL = Bundle.incito.url(forResource: "incito-webview.html", withExtension: nil)!
        
        webView.loadFileURL(htmlFileURL, allowingReadAccessTo: htmlFileURL.deletingLastPathComponent())
    
        // observe changes to the contentOffset, and trigger a re-render if needed.
        // we do this, rather than acting as delegate, as the users of the library may want to be the scrollview's delegate.
        scrollViewScrollObserver = scrollView.observe(\.contentOffset, options: [.old, .new]) { [weak self] (_, change) in
            guard let self = self, change.oldValue != change.newValue else { return }
            
            self.delegate?.incitoDidScroll(progress: self.scrollProgress, in: self)
        }
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapWebView))
        tap.delegate = self
        webView.addGestureRecognizer(tap)
    }
    
    deinit {
        scrollViewScrollObserver = nil
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        #warning("is this still needed?")
        // in < iOS 11.0 contentInset must be updated manually
//        if #available(iOS 11.0, *) { } else {
//            if self.automaticallyAdjustsScrollViewInsets {
//                scrollView.contentInset = UIEdgeInsets(top: self.topLayoutGuide.length,
//                                                       left: 0.0,
//                                                       bottom: self.bottomLayoutGuide.length,
//                                                       right: 0.0)
//                scrollView.scrollIndicatorInsets = scrollView.contentInset
//            }
//        }
    }
    
    /// Must be called on main queue
    public func update(incitoDocument: IncitoDocument){
        #warning("do this in the init?")
        
        self.incitoDocument = incitoDocument
        
        if self.isViewLoaded && !webView.isLoading {
            loadIncito()
        }

//        guard Thread.isMainThread else {
//            fatalError("update(renderableDocument:) must be called on the main queue.")
//        }
//
//        self.renderableDocument = renderableDocument
//
//        self.delegate?.incitoDocumentLoaded(in: self)
//
//        if self.isViewLoaded {
//            self.initializeRootView(parentSize: self.view.frame.size)
//        }
    }
    
    fileprivate func loadIncito() {
        guard let incitoDoc = incitoDocument else { return }
        
        webView.evaluateJavaScript("window.init(\(incitoDoc.json))") { [weak self] (_, error) in
            guard let self = self else { return }
            
            if error == nil {
                self.delegate?.incitoDocumentLoaded(in: self)
            } else {
                #warning("delegate error")
//                self.delegate?.incitoDocumentLoaded(in: self)
            }
        }
    }
    
    @objc fileprivate func didTapWebView(_ tap: UITapGestureRecognizer) {
        let location = tap.location(in: self.view)
        delegate?.incitoDidReceiveTap(at: location, in: self)
    }
}

extension IncitoViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
      return true
    }
}

extension IncitoViewController: WKNavigationDelegate, WKUIDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadIncito()
    }
    
    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            delegateOrDefault.incitoDidTapLink(url, in: self)
        }
        return nil
    }
}
    
    
//    fileprivate let scrollView = UIScrollView()
//    fileprivate var rootView: UIView?
//    fileprivate var renderableDocument: RenderableIncitoDocument? = nil
//    fileprivate var scrollViewScrollObserver: NSKeyValueObservation?
//    fileprivate var lastRenderedWindow: CGRect = .null
//    fileprivate let renderWindowInsets = UIEdgeInsets(top: -200, left: 0, bottom: -400, right: 0)
//

//    public override func viewDidLoad() {
//        super.viewDidLoad()
//
//        // configure the scrollView
//        view.addSubview(scrollView)
//        if #available(iOS 11.0, *) {
//            scrollView.contentInsetAdjustmentBehavior = .always
//        }
//
//        scrollView.translatesAutoresizingMaskIntoConstraints = false
//        NSLayoutConstraint.activate([
//            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
//            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
//            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
//            ])
//
//        initializeRootView(parentSize: self.view.frame.size)
//
//        // observe changes to the contentOffset, and trigger a re-render if needed.
//        // we do this, rather than acting as delegate, as the users of the library may want to be the scrollview's delegate.
//        scrollViewScrollObserver = scrollView.observe(\.contentOffset, options: [.old, .new]) { [weak self] (_, change) in
//            guard let self = self, change.oldValue != change.newValue else { return }
//
//            self.renderVisibleViews()
//
//            self.delegate?.incitoDidScroll(progress: self.scrollProgress, in: self)
//        }
//    }
//    deinit {
//        scrollViewScrollObserver = nil
//    }
//
//    public override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//
//        renderVisibleViews()
//    }
//
//    public override func viewDidLayoutSubviews() {
//        super.viewDidLayoutSubviews()
//
//        // in < iOS 11.0 contentInset must be updated manually
//        if #available(iOS 11.0, *) { } else {
//            if self.automaticallyAdjustsScrollViewInsets {
//                scrollView.contentInset = UIEdgeInsets(top: self.topLayoutGuide.length,
//                                                       left: 0.0,
//                                                       bottom: self.bottomLayoutGuide.length,
//                                                       right: 0.0)
//                scrollView.scrollIndicatorInsets = scrollView.contentInset
//            }
//        }
//    }
//
//    /// Must be called on main queue
//    public func update(renderableDocument: RenderableIncitoDocument) {
//        guard Thread.isMainThread else {
//            fatalError("update(renderableDocument:) must be called on the main queue.")
//        }
//
//        self.renderableDocument = renderableDocument
//
//        self.delegate?.incitoDocumentLoaded(in: self)
//
//        if self.isViewLoaded {
//            self.initializeRootView(parentSize: self.view.frame.size)
//        }
//        self._DEBUG_printLayout()
//    }
//
//    // MARK: - Initialization
//
//    /// Must be performed on main queue
//    private func initializeRootView(parentSize: CGSize) {
//
//        scrollView.backgroundColor = renderableDocument?.theme?.bgColor?.uiColor ?? .white
//
//        guard let rootRenderableView = renderableDocument?.rootView.value else {
//            self.rootView?.removeFromSuperview()
//            self.rootView = nil
//            return
//        }
//
//        let rootSize = rootRenderableView.layout.size.cgSize
//
//        let wrapper = UIView()
//
//        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapRootView))
//        wrapper.addGestureRecognizer(tap)
//
//        rootView = wrapper
//        scrollView.insertSubview(wrapper, at: 0)
//
//        wrapper.translatesAutoresizingMaskIntoConstraints = false
//        NSLayoutConstraint.activate([
//            wrapper.topAnchor.constraint(equalTo: scrollView.topAnchor),
//            wrapper.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
//            wrapper.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
//
//            wrapper.heightAnchor.constraint(equalToConstant: rootSize.height),
//            wrapper.widthAnchor.constraint(equalToConstant: rootSize.width)
//            ])
//
//        renderVisibleViews()
//    }
//
//
//
//    @objc
//    private func didTapRootView(_ tap: UITapGestureRecognizer) {
//
//        let delegate = self.delegate ?? DefaultDelegate()
//        let point = tap.location(in: self.view)
//
//        if let firstLinkable = self.firstView(at: point, where: { $1.style.link != nil }),
//            let link = firstLinkable.properties.style.link {
//            delegate.incitoDidTapLink(link, at: point, in: self)
//        } else {
//            delegate.incitoDidReceiveTap(at: point, in: self)
//        }
//    }
//
//    // MARK: - Rendering
//
//    fileprivate func renderVisibleViews(forced: Bool = false) {
//
//        guard let rootView = self.rootView else { return }
//        guard let renderableRootNode = self.renderableDocument?.rootView else { return }
//
//        let scrollRenderWindow: CGRect
//        if debug.showRenderWindows {
//            let height = scrollView.bounds.size.height
//            scrollRenderWindow = scrollView.bounds
//                .inset(by: UIEdgeInsets(top: height * 0.1, left: 0, bottom: height * 0.15, right: 0))
//        } else {
//            scrollRenderWindow = scrollView.bounds
//                .inset(by: renderWindowInsets)
//        }
//
//        // in RootView coord space
//        let renderWindow = scrollView.convert(scrollRenderWindow, to: rootView)
//
//        _DEBUG_updateWindowViews(in: lastRenderedWindow)
//
//        // dont re-render if no significant change in render window, unless forced
//        guard forced
//            || lastRenderedWindow.isNull
//            || lastRenderedWindow.size != renderWindow.size
//            || abs(lastRenderedWindow.origin.y - renderWindow.origin.y) > 50
//            else {
//            return
//        }
//
//        self.lastRenderedWindow = renderWindow
//
//        let visibleWindow = scrollView.convert(scrollView.bounds, to: rootView)
//
//        if let renderedRootView = renderableRootNode.renderVisibleNodes(
//            renderableRootViewWindow: renderWindow,
//            visibleRootViewWindow: visibleWindow,
//            didRender: { [weak self] renderableView, view in
//                guard let self = self else { return }
//                self.delegate?.incitoViewDidRender(
//                    view: view,
//                    with: renderableView.layout.viewProperties,
//                    in: self
//                )
//            },
//            didUnrender: { [weak self] renderableView, view in
//                guard let self = self else { return }
//                self.delegate?.incitoViewDidUnrender(
//                    view: view,
//                    with: renderableView.layout.viewProperties,
//                    in: self
//                )
//        }) {
//            rootView.addSubview(renderedRootView)
//        }
//
//        _DEBUG_updateOutlineViews(rootView: rootView, renderableRootNode: renderableRootNode)
//    }
//
//    // MARK: - Debug
//
//    public struct Debug {
//        public var showOutlines: Bool = false
//        public var showRenderWindows: Bool = false
//        public var printLayout: Bool = false
//        public var printLayoutDetails: Bool = false
//    }
//    public var debug: Debug = Debug() {
//        didSet {
//            self.renderVisibleViews(forced: true)
//        }
//    }
//
//    private var debugWindowViews = (top: UIView(), bottom: UIView())
//    private var debugOutlineViews: [UIView] = []
//
//    private func _DEBUG_printLayout() {
//        guard self.debug.printLayout,
//            let renderableDocument = self.renderableDocument else { return }
//
//        let debugTree: TreeNode<String> = renderableDocument.rootView.mapValues { renderableView, _, idx in
//            let layout = renderableView.layout
//            let name = layout.viewProperties.name ?? ""
//            let position = layout.position
//            let size = layout.size
//
//            var res = "\(idx)) \(name): [\(position)\(size)]"
//            if self.debug.printLayoutDetails {
//                res += "\n\t dimensions: \(layout.dimensions)\n"
//            }
//
//            return res
//        }
//
//        print("\(debugTree)")
//    }
//
//    private func _DEBUG_updateOutlineViews(rootView: UIView, renderableRootNode: TreeNode<RenderableView>) {
//
//        debugOutlineViews.forEach { $0.removeFromSuperview() }
//        if (self.debug.showOutlines) {
//            // shows a visibility-box around the the view
//            renderableRootNode.forEachNode { (node, _, _, _) in
//                let debugView = UIView()
//                debugView.layer.borderColor = UIColor.red.withAlphaComponent(0.5).cgColor
//                debugView.layer.borderWidth = 1
//                debugView.isUserInteractionEnabled = false
//                rootView.addSubview(debugView)
//                debugView.frame = node.value.absoluteRect
//
//                debugOutlineViews.append(debugView)
//            }
//        }
//    }
//
//    private func _DEBUG_updateWindowViews(in rootViewVisibleWindow: CGRect) {
//        guard debug.showRenderWindows else { return }
//
//        let overlayColor = UIColor.black.withAlphaComponent(0.2)
//
//        view.addSubview(debugWindowViews.top)
//        view.addSubview(debugWindowViews.bottom)
//        debugWindowViews.top.backgroundColor = overlayColor
//        debugWindowViews.top.isUserInteractionEnabled = false
//        debugWindowViews.bottom.backgroundColor = overlayColor
//        debugWindowViews.bottom.isUserInteractionEnabled = false
//
//        let debugViewVisibleWindow = rootView!.convert(rootViewVisibleWindow, to: view)
//
//        debugWindowViews.top.frame = CGRect(
//            x: 0, y: 0,
//            width: debugViewVisibleWindow.size.width,
//            height: debugViewVisibleWindow.origin.y
//        )
//
//        debugWindowViews.bottom.frame = CGRect(
//            x: 0, y: debugViewVisibleWindow.maxY,
//            width: debugViewVisibleWindow.size.width,
//            height: view.frame.size.height - debugViewVisibleWindow.maxY
//        )
//    }
//}

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
        
        let elementsAtJS = """
        [...document.elementsFromPoint(\(pointInWebView.x), \(pointInWebView.y))]
            .map(el => el.getAttribute('data-id'))
            .filter(el => el != null)
        """
        
        webView.evaluateJavaScript(elementsAtJS) { [weak self] (res, err) in
            guard let self = self else { return }
            
            let matchedElements: [IncitoDocument.Element] = (res as? [String])
                .flatMap({ matchedIds in
                    self.incitoDocument?.elements.filter({
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
    public func getBoundsOfElement(withId elementId: String, completion: @escaping (CGRect?) -> Void) {
        
        let boundsOfElJS = "boundsOfElementWithId('\(elementId)')"
        
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
        withId elementId: String,
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
