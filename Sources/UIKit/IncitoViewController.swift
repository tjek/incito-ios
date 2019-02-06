//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

/// A document whose viewNodes are RenderableViews
public typealias RenderableIncitoDocument = IncitoDocument<RenderableView>

/**
 possible delegate methods:
 - configure scrollView
 */
public protocol IncitoViewControllerDelegate: class {
    
    /// Called whenever a document is updated.
    func incitoDocumentLoaded(in viewController: IncitoViewController)
    
    /// Called whenever a view element is rendered (triggered while scrolling, so this must not do heavy work)
    func incitoViewDidRender(view: UIView, with viewProperties: ViewProperties, in viewController: IncitoViewController)
    
    /// Called whenever a view element is about to be removed from the view hierarchy (triggered while scrolling, so this must not do heavy work)
    func incitoViewDidUnrender(view: UIView, with viewProperties: ViewProperties, in viewController: IncitoViewController)
    
    func incitoDidReceiveTap(at point: CGPoint, in viewController: IncitoViewController)
    
    func incitoDidScroll(progress: Double, in viewController: IncitoViewController)
}

public class IncitoViewController: UIViewController {
    weak var delegate: IncitoViewControllerDelegate?
    
    /// 0-1 percentage of the screen that we are currently scrolled to. Can be <0 or >1 when over-scrolling.
    public var scrollProgress: Double {
        return scrollView.percentageProgress
    }
    
    public let scrollView = UIScrollView()
    private var rootView: UIView?
    private(set) var renderableDocument: RenderableIncitoDocument? = nil
    
    public struct Debug {
        public var showOutlines: Bool = false
        public var showRenderWindows: Bool = false
        public var printLayout: Bool = false
        public var printLayoutDetails: Bool = false
    }
    public var debug: Debug = Debug() {
        didSet {
            self.renderVisibleViews(forced: true)
        }
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // configure the scrollView
        view.addSubview(scrollView)
        
        scrollView.alwaysBounceVertical = true
        scrollView.delegate = self
        if #available(iOS 11.0, *) {
            scrollView.contentInsetAdjustmentBehavior = .always
        }
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
        
        initializeRootView(parentSize: self.view.frame.size)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        renderVisibleViews()
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        renderVisibleViews()
    }
    
    /// Must be called on main queue
    public func update(renderableDocument: RenderableIncitoDocument) {
        guard Thread.isMainThread else {
            fatalError("update(renderableDocument:) must be called on the main queue.")
        }
        
        self.renderableDocument = renderableDocument
        
        self.delegate?.incitoDocumentLoaded(in: self)
        
        initializeRootView(parentSize: self.view.frame.size)
        
        if self.debug.printLayout {
            let debugTree: TreeNode<String> = renderableDocument.rootView.mapValues { renderableView, _, idx in
                let layout = renderableView.layout
                let name = layout.viewProperties.name ?? ""
                let position = layout.position
                let size = layout.size
                
                var res = "\(idx)) \(name): [\(position)\(size)]"
                if self.debug.printLayoutDetails {
                    res += "\n\t dimensions: \(layout.dimensions)\n"
                }
                
                return res
            }
            
            print("\(debugTree)")
        }
        
    }
    
    /// Must be performed on main queue
    private func initializeRootView(parentSize: CGSize) {
        
        scrollView.backgroundColor = renderableDocument?.theme?.bgColor?.uiColor ?? .white
        
        guard let rootRenderableView = renderableDocument?.rootView.value else {
            self.rootView?.removeFromSuperview()
            self.rootView = nil
            return
        }
        
        let rootSize = rootRenderableView.layout.size.cgSize
        
        let wrapper = UIView()
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapRootView))
        wrapper.addGestureRecognizer(tap)
        
        rootView = wrapper
        scrollView.insertSubview(wrapper, at: 0)
        
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            wrapper.topAnchor.constraint(equalTo: scrollView.topAnchor),
            wrapper.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            wrapper.leftAnchor.constraint(greaterThanOrEqualTo: scrollView.leftAnchor),
            wrapper.rightAnchor.constraint(lessThanOrEqualTo: scrollView.rightAnchor),
            wrapper.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            
            wrapper.heightAnchor.constraint(equalToConstant: rootSize.height),
            wrapper.widthAnchor.constraint(equalToConstant: parentSize.width)
            ])
        
        renderVisibleViews()
    }
    
    @objc
    func didTapRootView(_ tap: UITapGestureRecognizer) {
        
        guard let delegate = self.delegate else { return }
        
        let point = tap.location(in: self.view)
        delegate.incitoDidReceiveTap(at: point, in: self)
    }
    
    // MARK: - Rendering
    
    private var lastRenderedWindow: CGRect = .null
    private let renderWindowInsets = UIEdgeInsets(top: -200, left: 0, bottom: -400, right: 0)
    
    func renderVisibleViews(forced: Bool = false) {
        
        guard let rootView = self.rootView else { return }
        guard let renderableRootNode = self.renderableDocument?.rootView else { return }
        
        let scrollVisibleWindow: CGRect
        if debug.showRenderWindows {
            let height = scrollView.bounds.size.height
            scrollVisibleWindow = scrollView.bounds
                .inset(by: UIEdgeInsets(top: height * 0.1, left: 0, bottom: height * 0.15, right: 0))
        } else {
            scrollVisibleWindow = scrollView.bounds
                .inset(by: renderWindowInsets)
        }
        
        // in RootView coord space
        let renderWindow = scrollView.convert(scrollVisibleWindow, to: rootView)
        
        if debug.showRenderWindows {
            updateDebugWindowViews(in: lastRenderedWindow)
        }
        
        // dont re-render if no significant change in render window, unless forced
        guard forced
            || lastRenderedWindow.isNull
            || lastRenderedWindow.size != renderWindow.size
            || abs(lastRenderedWindow.origin.y - renderWindow.origin.y) > 50
            else {
            return
        }
        
        self.lastRenderedWindow = renderWindow
        
        if let renderedRootView = renderableRootNode.renderVisibleNodes(
            visibleRootViewWindow: renderWindow,
            didRender: { [weak self] renderableView, view in
                guard let self = self else { return }
                self.delegate?.incitoViewDidRender(
                    view: view,
                    with: renderableView.layout.viewProperties,
                    in: self
                )
            },
            didUnrender: { [weak self] renderableView, view in
                guard let self = self else { return }
                self.delegate?.incitoViewDidUnrender(
                    view: view,
                    with: renderableView.layout.viewProperties,
                    in: self
                )
        }) {
            rootView.addSubview(renderedRootView)
        }
        
        debugOutlineViews.forEach { $0.removeFromSuperview() }
        if (self.debug.showOutlines) {
            // shows a visibility-box around the the view
            renderableRootNode.forEachNode { (node, _, _, _) in
                let debugView = UIView()
                debugView.layer.borderColor = UIColor.red.withAlphaComponent(0.5).cgColor
                debugView.layer.borderWidth = 1
                debugView.isUserInteractionEnabled = false
                rootView.addSubview(debugView)
                debugView.frame = node.value.absoluteRect
                
                debugOutlineViews.append(debugView)
            }
        }
    }
    
    // MARK: - Debug
    
    private var debugWindowViews = (top: UIView(), bottom: UIView())
    private var debugOutlineViews: [UIView] = []
    
    func updateDebugWindowViews(in rootViewVisibleWindow: CGRect) {
        let overlayColor = UIColor.black.withAlphaComponent(0.2)
        
        view.addSubview(debugWindowViews.top)
        view.addSubview(debugWindowViews.bottom)
        debugWindowViews.top.backgroundColor = overlayColor
        debugWindowViews.top.isUserInteractionEnabled = false
        debugWindowViews.bottom.backgroundColor = overlayColor
        debugWindowViews.bottom.isUserInteractionEnabled = false
        
        let debugViewVisibleWindow = rootView!.convert(rootViewVisibleWindow, to: view)
        
        debugWindowViews.top.frame = CGRect(
            x: 0, y: 0,
            width: debugViewVisibleWindow.size.width,
            height: debugViewVisibleWindow.origin.y
        )
        
        debugWindowViews.bottom.frame = CGRect(
            x: 0, y: debugViewVisibleWindow.maxY,
            width: debugViewVisibleWindow.size.width,
            height: view.frame.size.height - debugViewVisibleWindow.maxY
        )
    }
}

extension IncitoViewController: UIScrollViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        renderVisibleViews()
        
        self.delegate?.incitoDidScroll(progress: self.scrollProgress, in: self)
    }
}

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
}

extension IncitoViewController {
    
    /// Walk through all the loaded elements.
    public func iterateViewElements(_ body: @escaping (ViewProperties, _ stop: inout Bool) -> Void) {
        guard let rootNode = self.renderableDocument?.rootView else { return }
        
        rootNode.forEachNode { (renderableNode, _, _, stop) in
            
            let renderableView = renderableNode.value
            
            body(renderableView.layout.viewProperties, &stop)
        }
    }
    
    /**
     - parameter point: The point in the receiver's `view`'s coordinate space.
     - parameter predicate: A predicate to decide which view under the specified point to return.
     */
    public func firstView(at point: CGPoint, where predicate: (UIView?, ViewProperties) -> Bool) -> (view: UIView, properties: ViewProperties)? {
        
        let treeLocation = self.view.convert(point, to: self.scrollView)
        
        let renderableViewNode = self.renderableDocument?.rootView.first { (node, stopBranch) -> Bool in
            let renderableView = node.value
            
            let absoluteRect = renderableView.absoluteRect

            guard absoluteRect.contains(treeLocation) else {
                stopBranch = true
                return false
            }
            
            return predicate(renderableView.renderedView, renderableView.layout.viewProperties)
        }
        
        if let renderableNode = renderableViewNode {            
            // make sure the view is rendered
            let renderedViews = renderableNode.renderAllChildNodes(didRender: { _, _ in }, didUnrender: { _, _ in })
            return (renderedViews, renderableNode.value.layout.viewProperties)
        } else {
            return nil
        }
    }
    
    // TODO: option where on screen to scroll element to.
    public func scrollToElement(withId elementId: ViewProperties.Identifier, animated: Bool) {
        
        guard let root = self.rootView else { return }
        
        // TODO: keep dictionary of view/ids to improve performance
        let renderableViewNode = self.renderableDocument?.rootView.first { node, _ in
            node.value.layout.viewProperties.id == elementId
        }
        
        guard let renderableView = renderableViewNode?.value else {
            return
        }
        
        // the view's rect within the scrollview
        let scrollRect =  root.convert(renderableView.absoluteRect, to: self.scrollView)
        
        // TODO: tweak so that it is the size of the frame, centered around the scrollRect
        let centeredRect = CGRect(
            x: scrollRect.origin.x + scrollRect.size.width/2.0 - self.scrollView.frame.size.width/2.0,
            y: scrollRect.origin.y + scrollRect.size.height/2.0 - self.scrollView.frame.size.height/2.0,
            width: self.scrollView.frame.size.width,
            height: self.scrollView.frame.size.height
        )
        
        self.scrollView.scrollRectToVisible(centeredRect, animated: animated)
    }
}
