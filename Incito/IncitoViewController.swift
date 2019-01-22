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
        
//        DispatchQueue.global().async {
//
//            let startA = Date.timeIntervalSinceReferenceDate
//
//
//            let layouterTree = rootIncitoView.generateLayouterTree(
//                layoutType: .block,
//                intrinsicViewSizer: intrinsicSizer
//            )
//
//            let dimensionsTree = layouterTree.resolve(rootSize: parentSize)
//
//            let oldRenderableTree = dimensionsTree.OLD_buildRenderableViewTree(
//                rendererProperties: self.renderer,
//                nodeBuilt: { _ in }
//            )
//
//            let endA = Date.timeIntervalSinceReferenceDate
//            DispatchQueue.main.async {
//                print(" ⇢ 🚧 [OLD] Built layout graph: \(round((endA - startA) * 1_000))ms")
//            }
//        }
        
        let startB = Date.timeIntervalSinceReferenceDate
        
        let layoutTree = rootIncitoView.layout(
            rootSize: parentSize,
            intrinsicSizerBuilder: intrinsicSizer
        )
        
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
        let endB = Date.timeIntervalSinceReferenceDate
        print(" ⇢ 🚧 [NEW] Built layout graph: \(round((endB - startB) * 1_000))ms")
        
        self.delegate?.documentLoaded(incito: self.incitoDocument, in: self)
        
        if self.printDebugLayout {
            let debugTree: TreeNode<String> = layoutTree.mapValues { layout, _, idx in
                
                let name = layout.viewProperties.name ?? ""
                let position = layout.position
                let size = layout.size
                
                let res = "\(idx)) \(name): [\(position)\(size)]"
                //                + "\n\t dimensions: \(layout.dimensions)"
                
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
    
    var showDebugOutlines: Bool = false
    var showDebugRenderWindow: Bool = false
    var printDebugLayout: Bool = false
    
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

struct ViewInteractionProperties {
    let tapCallback: ((UIView) -> Void)?
    let peekable: Bool
}

class RenderableView {
    let layout: ViewLayout
    let absoluteTransform: CGAffineTransform // the sum of all the parent view's transformations. Includes the localPosition translation.
    let siblingIndex: Int // The index of this view in relation to its siblings
    let renderer: (RenderableView) -> UIView
    let interactionProperties: ViewInteractionProperties?
    
    fileprivate var renderedView: UIView? = nil
    
    init(
        layout: ViewLayout,
        absoluteTransform: CGAffineTransform,
        siblingIndex: Int,
        renderer: @escaping (RenderableView) -> UIView,
        interactionProperties: ViewInteractionProperties?
        ) {
        self.layout = layout
        self.absoluteTransform = absoluteTransform
        self.siblingIndex = siblingIndex
        self.renderer = renderer
        self.interactionProperties = interactionProperties
    }
    
    @discardableResult
    func render() -> UIView {
        if let view = renderedView {
            return view
        }
        
        let view = renderer(self)
        
        self.renderedView = view
        view.tag = siblingIndex + 1 // add 1 so non-sibling subviews stay at the bottom
        
        if self.interactionProperties?.tapCallback != nil {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapView))
            view.addGestureRecognizer(tapGesture)
        }
        
        return view
    }
    
    func unrender() {
        renderedView?.removeFromSuperview()
        renderedView = nil
    }
    
    var absoluteRect: CGRect {
        return CGRect(origin: .zero, size: layout.size.cgSize)
            .applying(absoluteTransform)
    }
    
    @objc
    func didTapView(_ tap: UITapGestureRecognizer) {
        guard let tapCallback = self.interactionProperties?.tapCallback, let view = self.renderedView else { return }
        
        tapCallback(view)
    }
}

extension TreeNode where T == RenderableView {
    
    func renderVisibleNodes(visibleRootViewWindow: CGRect, didRender: @escaping (RenderableView, UIView) -> Void, didUnrender: @escaping (RenderableView, UIView) -> Void) -> UIView? {
        return self.renderAllChildNodes(where: { renderableView in
            let absoluteRect = renderableView.absoluteRect
            
            // TODO: if it doesnt clip, build from sum of all children, incase the children are larger than the node?
            
            // only render if its visible
            return visibleRootViewWindow.intersects(absoluteRect)
            
        }, didRender: didRender, didUnrender: didUnrender)
    }
    
    func renderAllChildNodes(where predicate: (RenderableView) -> Bool, didRender: @escaping (RenderableView, UIView) -> Void, didUnrender: @escaping (RenderableView, UIView) -> Void) -> UIView? {
        
        guard predicate(self.value) else {
            self.unrenderAllChildNodes(didUnrender: didUnrender)
            return nil
        }
        
        let renderedView = self.value.render()
        didRender(self.value, renderedView)
        
        for childNode in self.children {
            guard let childView = childNode.renderAllChildNodes(where: predicate, didRender: didRender, didUnrender: didUnrender) else {
                continue
            }
            
            // add the childView to the parentView, at the correct z-index
            let parentContents: UIView = {
                switch renderedView {
                case let v as RoundedShadowedView:
                    return v.childContainer
                default:
                    return renderedView
                }
            }()
            if let prevSibling = parentContents.subviews.last(where: { $0.tag < childView.tag }) {
                parentContents.insertSubview(childView, aboveSubview: prevSibling)
            } else {
                parentContents.insertSubview(childView, at: 0)
            }
        }
        
        return renderedView
    }
    
    func unrenderAllChildNodes(didUnrender: @escaping (RenderableView, UIView) -> Void) {
        let oldView = self.value.renderedView
        
        self.value.unrender()
        
        if let renderedView = oldView {
            didUnrender(self.value, renderedView)
        }
        
        for childNode in self.children {
            childNode.unrenderAllChildNodes(didUnrender: didUnrender)
        }
    }
    
    func renderAllChildNodes(didRender: @escaping (RenderableView, UIView) -> Void, didUnrender: @escaping (RenderableView, UIView) -> Void) -> UIView {
        return self.renderAllChildNodes(where: { _ in true }, didRender: didRender, didUnrender: didUnrender)!
    }
}

extension TreeNode where T == ViewLayout {
    func buildRenderableViewTree(rendererProperties: IncitoRenderer, nodeBuilt: (RenderableView) -> Void) -> TreeNode<RenderableView> {
        
        let interactionBuilder: (ViewProperties) -> ViewInteractionProperties? = { viewProperties in
            let alphaTap: (UIView) -> Void = { view in
                view.alpha = 1 + (0.5 - view.alpha)
                print("Tapped Section!", view)
            }
            switch viewProperties.style.role {
            case "section"?:
                return ViewInteractionProperties(tapCallback: alphaTap, peekable: false)
                
            case "offer"?:
                return ViewInteractionProperties(tapCallback: alphaTap, peekable: true)
                
            default:
                return nil
            }
        }
        
        return self.mapValues { (viewLayout, newParent, index) in
            
            let viewProperties = viewLayout.viewProperties
            let dimensions = viewLayout.dimensions
            let localPosition = viewLayout.position
            
            let parentSize = newParent?.value.layout.size ?? .zero
            let parentTransform = newParent?.value.absoluteTransform ?? .identity
            
            let localMove = CGAffineTransform.identity
                .translatedBy(x: CGFloat(localPosition.x),
                              y: CGFloat(localPosition.y))
            
            let transform = CGAffineTransform.identity
                .concatenating(dimensions.layoutProperties.transform.affineTransform)
                .concatenating(localMove)
                .concatenating(parentTransform)
            
            let renderer = buildViewRenderer(rendererProperties, viewType: viewProperties.type, parentSize: parentSize)
            
            let renderableView = RenderableView(
                layout: viewLayout,
                absoluteTransform: transform,
                siblingIndex: index,
                renderer: renderer,
                interactionProperties: interactionBuilder(viewProperties)
            )
            
            nodeBuilt(renderableView)
            
            return renderableView
        }
    }
}

func buildViewRenderer(_ renderProperties: IncitoRenderer, viewType: ViewType, parentSize: Size<Double>) -> (RenderableView) -> UIView {
    
    let renderer: (RenderableView) -> UIView
    
    switch viewType {
    case let .text(textProperties):
        renderer = { renderableView in
            
            let container = RoundedShadowedView(renderableView: renderableView)
            
            UIView.addTextView(
                into: container,
                textProperties: textProperties,
                fontProvider: renderProperties.fontProvider,
                textDefaults: renderProperties.theme?.textDefaults ?? .empty,
                size: renderableView.layout.size,
                padding: renderableView.layout.dimensions.layoutProperties.padding,
                intrinsicSize: renderableView.layout.dimensions.intrinsicSize
            )
            
            return container
        }
        
    case let .image(imageProperties):
        renderer = { renderableView in
            let container = RoundedShadowedView(renderableView: renderableView)

            let imgReq = UIView.addImageView(
                into: container.childContainer,
                imageProperties: imageProperties
            )
            
            renderProperties.imageViewLoader(imgReq)
            return container
        }
    case .view,
         .absoluteLayout,
         .flexLayout:
        renderer = { renderableView in
            return RoundedShadowedView(renderableView: renderableView)
        }
    default:
        renderer = { renderableView in
            return RoundedShadowedView(renderableView: renderableView)
        }
    }
    
    return { renderableView in
        let view = renderer(renderableView)
        
        // apply the style properties to the view
        let imageRequest = view.applyStyle(
            renderableView.layout.viewProperties.style,
            transform: renderableView.layout.dimensions.layoutProperties.transform,
            parentSize: parentSize
        )
        // perform any image loading
        if let imgReq = imageRequest {
            renderProperties.imageViewLoader(imgReq)
        }
        
        return view
    }
}

extension UIView {
    
    static func addTextView(
        into container: UIView,
        textProperties: TextViewProperties,
        fontProvider: FontProvider,
        textDefaults: TextViewDefaultProperties,
        size: Size<Double>,
        padding: Edges<Double>,
        intrinsicSize: Size<Double?>
        ) {
        
        let label = UILabel()
        
        if let s = textProperties.shadow {
            label.layer.applyShadow(s)
        }
        
        // TODO: cache these values from when doing the layout phase
        let attributedString = textProperties.attributedString(
            fontProvider: fontProvider,
            defaults: textDefaults
        )
        
        label.attributedText = attributedString
        label.numberOfLines = textProperties.maxLines
        
        label.textAlignment = (textProperties.textAlignment ?? .left).nsTextAlignment
        label.lineBreakMode = .byTruncatingTail
        label.backgroundColor = .clear
        
        // labels are vertically aligned in incito, so add to a container view
        container.insertSubview(label, at: 0)
        
        let containerInnerSize = size.inset(padding)
        let textHeight: Double = {
            if let h = intrinsicSize.height {
                return h
            }
            // it may not have an intrinsic height calculated yet (eg. if the view container has absolute height specified)
            return Double(ceil(label.sizeThatFits(CGSize(width: containerInnerSize.width, height: 0)).height))
        }()
        
        label.frame = CGRect(
            origin: CGPoint(
                x: padding.left,
                y: padding.top
            ),
            size: CGSize(
                width: containerInnerSize.width,
                height: textHeight
            )
        )
        label.autoresizingMask = [.flexibleBottomMargin, .flexibleRightMargin]
    }
    
    
    static func addImageView(
        into container: UIView,
        imageProperties: ImageViewProperties
        ) -> ImageViewLoadRequest {
        
        let size = container.bounds.size
        let transform: (UIImage) -> UIImage = {
            $0.resized(scalingType: .centerCrop, into: size)
        }
        
        let imageLoadReq = ImageViewLoadRequest(url: imageProperties.source, transform: transform) { [weak container] loadedImageView in
            guard let c = container else { return }
            if let imageView = loadedImageView {
                imageView.contentMode = .scaleToFill
                imageView.frame = c.bounds
                imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                imageView.alpha = 0
                c.insertSubview(imageView, at: 0)
                
                UIView.animate(withDuration: 0.2) {
                    imageView.alpha = 1
                }
                
            } else {
                UIView.animate(withDuration: 0.2) {
                    c.backgroundColor = .red
                }
            }
        }
        
        return imageLoadReq
    }
}

extension UIImage {
    func resized(scalingType: BackgroundImage.ScaleType, into containerSize: CGSize) -> UIImage {
        let imageSize = self.size
        
        // calculate how much the image needs to be scaled to fill or fit the container, depending on the scale type
        let fitFillScale: CGFloat = {
            if containerSize.width == 0 || containerSize.height == 0 || imageSize.width == 0 || imageSize.height == 0 {
                return 1
            }
            switch scalingType {
            case .centerCrop:
                // fill container. No tiling necessary.
                let scaleX = imageSize.width / containerSize.width
                let scaleY = imageSize.height / containerSize.height
                return min(scaleX, scaleY)
                
            case .centerInside:
                // fit container
                let scaleX = imageSize.width / containerSize.width
                let scaleY = imageSize.height / containerSize.height
                return max(scaleX, scaleY)
                
            case .none:
                // original size
                return 1
            }
        }()
        
        if fitFillScale == 1 {
            return self
        } else {
            let targetSize = CGSize(
                width: imageSize.width / fitFillScale,
                height: imageSize.height / fitFillScale
            )
            let newImage = self.resized(to: targetSize)
            print("Resizing \(imageSize) -> \(targetSize)")
            return newImage
        }
    }
}

extension UIView {
    func applyStyle(
        _ style: StyleProperties,
        transform: Transform<Double>,
        parentSize: Size<Double>
        ) -> ImageViewLoadRequest? {
        
        // apply the layout.view properties
        backgroundColor = style.backgroundColor?.uiColor ?? .clear
        clipsToBounds = style.clipsChildren
        
        var imageLoadReq: ImageViewLoadRequest? = nil
        if let bgImage = style.backgroundImage {
            
            let size = self.bounds.size
            let transform: (UIImage) -> UIImage = {
                $0.resized(scalingType: bgImage.scale, into: size)
            }
            
            imageLoadReq = ImageViewLoadRequest(url: bgImage.source, transform: transform) { [weak self] loadedImageView in
                guard let self = self else { return }
                
                if let imageView = loadedImageView {
                    imageView.frame = self.bounds
                    imageView.applyBackground(
                        position: bgImage.position,
                        scalingType: bgImage.scale,
                        tilingMode: bgImage.tileMode
                    )
                    
                    imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    imageView.alpha = 0
                    self.insertSubview(imageView, at: 0)
                    
                    UIView.animate(withDuration: 0.2) {
                        imageView.alpha = 1
                    }
                    
                } else {
                    UIView.animate(withDuration: 0.2) {
                        self.backgroundColor = .red
                    }
                }
            }
        }
        
        // TODO: use real anchor point
        self.setAnchorPoint(anchorPoint: CGPoint.zero)
        
        self.transform = self.transform
            .concatenating(transform.affineTransform)
        
        return imageLoadReq
    }
}

extension Transform where TranslateValue == Double {
    var affineTransform: CGAffineTransform {
        return CGAffineTransform.identity
            .translatedBy(x: CGFloat(translate.x), y: CGFloat(translate.y))
            .rotated(by: CGFloat(rotate))
            .scaledBy(x: CGFloat(scale), y: CGFloat(scale))
    }
}
