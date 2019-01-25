//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

/**
 possible delegate methods:
 - configure scrollView
 */
protocol IncitoViewControllerDelegate: class {
    // incito did load
    // viewDidAppear/viewDidDisappear
    func viewDidRender(view: UIView, with viewProperties: ViewProperties, in viewController: IncitoViewController)
    func viewDidUnrender(view: UIView, with viewProperties: ViewProperties, in viewController: IncitoViewController)
    
    /// Called _once_ for every view element when the incito document is loaded.
    /// It is an opportunity to index the properties of the views.
    func viewElementLoaded(viewProperties: ViewProperties, incito: IncitoDocument, in viewController: IncitoViewController)
    func documentLoaded(incito: IncitoDocument, in viewController: IncitoViewController)
}

class IncitoViewController: UIViewController {
    weak var delegate: IncitoViewControllerDelegate?
    
    let scrollView = UIScrollView()
    
    let incitoDocument: IncitoDocument
    
    var rootView: UIView?
    var renderer: IncitoRenderer
    
    var showDebugOutlines: Bool = false
    var showDebugRenderWindow: Bool = false
    var printDebugLayout: Bool = false
    var printDebugLayoutDetails: Bool = true
    
    init(incito: IncitoDocument) {
        self.incitoDocument = incito
        self.renderer = IncitoRenderer(
            fontProvider: UIFont.systemFont(forFamily:size:),
            imageViewLoader: loadImageView,
            theme: incitoDocument.theme
        )
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
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
        
        scrollView.backgroundColor = incitoDocument.theme?.bgColor?.uiColor ?? .white
        
        let fontAssets = self.incitoDocument.fontAssets
        let parentSize = Size(cgSize: self.view.frame.size)

        queue.async { [weak self] in
            self?.loadFonts(fontAssets: fontAssets) { [weak self] in
                self?.buildLayout(parentSize: parentSize)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        renderVisibleViews()
    }
    
    // loadFonts -> buildLayout -> buildCallbacks
    
    let queue = DispatchQueue(label: "IncitoViewControllerQueue", qos: .userInitiated)
    
    func loadFonts(fontAssets: [FontAssetName: FontAsset], completion: @escaping () -> Void) {
        
        let fontLoader = FontAssetLoader.uiKitFontAssetLoader()
        
        let startFontLoad = Date.timeIntervalSinceReferenceDate
        fontLoader.loadAndRegisterFontAssets(fontAssets) { [weak self] (loadedAssets) in
            
            let endFontLoad = Date.timeIntervalSinceReferenceDate
            print(" ⇢ 🔠 Downloaded font assets: \(loadedAssets.count) in \(round((endFontLoad - startFontLoad) * 1_000))ms")
            loadedAssets.forEach { asset in
                print("    ‣ '\(asset.assetName)': \(asset.fontName)")
            }
            
            self?.queue.async { [weak self] in
                // update the renderer's fontProvider
                self?.renderer.fontProvider = loadedAssets.font(forFamily:size:)
                
                completion()
            }
        }
    }
    
    func buildLayout(parentSize: Size<Double>) {
        
        let rootIncitoView: ViewNode = incitoDocument.rootView
        let fontProvider = self.renderer.fontProvider
        let defaultTextProperties = incitoDocument.theme?.textDefaults ?? .empty

        let intrinsicSizer = uiKitViewSizer(
            fontProvider: fontProvider,
            textDefaults: defaultTextProperties
        )
        
        var layoutTree: TreeNode<ViewLayout>!
        print(" ⇢ 🚧 Building LayoutTree...")
        measure("   Total", timeScale: .milliseconds) {
            layoutTree = rootIncitoView.layout(
                rootSize: parentSize,
                intrinsicSizerBuilder: intrinsicSizer
            )
        }
        
        measure(" ⇢ 🚧 Renderable Tree", timeScale: .milliseconds) {
            self.renderableTree = layoutTree.buildRenderableViewTree(
                rendererProperties: self.renderer,
                nodeBuilt: { [weak self] renderableView in
                    guard let self = self else { return }
                    self.delegate?.viewElementLoaded(
                        viewProperties: renderableView.layout.viewProperties,
                        incito: self.incitoDocument,
                        in: self
                    )
                }
            )
        }
        
        self.delegate?.documentLoaded(incito: self.incitoDocument, in: self)
        
        if self.printDebugLayout {
            let debugTree: TreeNode<String> = layoutTree.mapValues { layout, _, idx in
                
                let name = layout.viewProperties.name ?? ""
                let position = layout.position
                let size = layout.size
                
                var res = "\(idx)) \(name): [\(position)\(size)]"
                if printDebugLayoutDetails {
                    res += "\n\t dimensions: \(layout.dimensions)\n"
                }
                
                return res
            }
            
            print("\(debugTree)")
        }
        DispatchQueue.main.async { [weak self] in
            self?.initializeRootView(parentSize: parentSize.cgSize)
        }
    }
    
    var renderableTree: TreeNode<RenderableView>? = nil
    // Must be performed on main queue
    func initializeRootView(parentSize: CGSize) {
        
        guard let rootRenderableView = renderableTree?.value else { return }
        
        let rootSize = rootRenderableView.layout.size.cgSize
        
        let wrapper = UIView()
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
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        // TODO: `unrender` all the rendered RenderableSections (prioritizing those above)
    }
    
    var lastRenderedWindow: CGRect?
    
    var debugWindowViews = (top: UIView(), bottom: UIView())
    var debugOutlineViews: [UIView] = []
    
    func renderVisibleViews() {
        
        guard let rootView = self.rootView else { return }
        guard let renderableRootNode = self.renderableTree else { return }
        
        
        let scrollVisibleWindow: CGRect
        
        if showDebugRenderWindow {
            scrollVisibleWindow = scrollView.bounds
                .inset(by: UIEdgeInsets(top: 120, left: 0, bottom: 150, right: 0))
        } else {
            scrollVisibleWindow = scrollView.bounds
                .inset(by: UIEdgeInsets(top: -200, left: 0, bottom: -400, right: 0))
        }
        

        // in RootView coord space
        let renderWindow = scrollView.convert(scrollVisibleWindow, to: rootView)
        
//        // dont do rendercheck until we've scrolled a certain amount
//        if let lastRendered = self.lastRenderedWindow,
//            abs(lastRendered.origin.y - renderWindow.origin.y) < 50 {
//            return
//        }
        
        self.lastRenderedWindow = renderWindow
        
        if showDebugRenderWindow {
            updateDebugWindowViews(in: renderWindow)
        }
        
        if let renderedRootView = renderableRootNode.renderVisibleNodes(
            visibleRootViewWindow: renderWindow,
            didRender: { [weak self] renderableView, view in
                guard let self = self else { return }
                self.delegate?.viewDidRender(
                    view: view,
                    with: renderableView.layout.viewProperties,
                    in: self
                )
            },
            didUnrender: { [weak self] renderableView, view in
                guard let self = self else { return }
                self.delegate?.viewDidUnrender(
                    view: view,
                    with: renderableView.layout.viewProperties,
                    in: self
                )
        }) {
            rootView.addSubview(renderedRootView)
        }
        
        debugOutlineViews.forEach { $0.removeFromSuperview() }
        if (self.showDebugOutlines) {
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
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        renderVisibleViews()
    }
}

extension IncitoViewController {
    func firstView(at point: CGPoint, where predicate: (UIView?, ViewProperties) -> Bool) -> (UIView, ViewProperties)? {
        
        let treeLocation = self.view.convert(point, to: self.scrollView)
        
        let renderableViewNode = self.renderableTree?.first { (node, stopBranch) -> Bool in            
            let renderableView = node.value
            
            let absoluteRect = renderableView.absoluteRect

            guard absoluteRect.contains(treeLocation) else {
                stopBranch = true
                return false
            }
            
            return predicate(renderableView.renderedView, renderableView.layout.viewProperties)
        }
        
        if let renderableNode = renderableViewNode {
            
            let renderedViews = renderableNode.renderAllChildNodes(didRender: { _, _ in }, didUnrender: { _, _ in })
            // make sure the view is rendered
            return (renderedViews, renderableNode.value.layout.viewProperties)
        } else {
            return nil
        }
    }
    
    
    func scrollToElement(withId elementId: ViewProperties.Identifier, animated: Bool) {
        
        guard let root = self.rootView else { return }
        
        // TODO: keep dictionary of view/ids to improve performance
        let renderableViewNode = self.renderableTree?.first { node, _ in
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
