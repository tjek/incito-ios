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
            imageViewLoader: loadImageView(url:completion:),
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

        let start = Date.timeIntervalSinceReferenceDate
        
        let intrinsicSizer = uiKitViewSizer(
            fontProvider: fontProvider,
            textDefaults: defaultTextProperties
        )
        
        let layouterTree = rootIncitoView.generateLayouterTree(
            layoutType: .block,
            intrinsicViewSizer: intrinsicSizer
        )
        
        let dimensionsTree = layouterTree.resolve(rootSize: parentSize)
        
        self.renderableTree = dimensionsTree.buildRenderableViewTree(rendererProperties: self.renderer)
        
        let end = Date.timeIntervalSinceReferenceDate
        print(" ⇢ 🚧 Built layout graph: \(round((end - start) * 1_000))ms")
        
//        let debugTree = dimensionsTree.mapValues { value, _, idx in
//            "\(idx)) \(value.view.id ?? "?"): [ size \(value.dimensions.size), pos \(value.position), margins \(value.dimensions.layout.margins), padding \(value.dimensions.layout.padding) ]"
//        }
//
//        print("\(debugTree)")
        
        DispatchQueue.main.async { [weak self] in
            self?.initializeRootView(parentSize: parentSize.cgSize)
        }
    }
    
    var renderableTree: TreeNode<RenderableView>? = nil
    // Must be performed on main queue
    func initializeRootView(parentSize: CGSize) {
        
        guard let rootRenderableView = renderableTree?.value else { return }
        
        let rootSize = rootRenderableView.dimensions.size.cgSize
        
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
    
    func renderVisibleViews() {
        
        guard let rootView = self.rootView else { return }
        guard let renderableRootNode = self.renderableTree else { return }
        
        let scrollVisibleWindow = scrollView.bounds
//            .inset(by: UIEdgeInsets(top: 120, left: 0, bottom: 150, right: 0))
            .inset(by: UIEdgeInsets(top: -200, left: 0, bottom: -400, right: 0))

        // in RootView coord space
        let renderWindow = scrollView.convert(scrollVisibleWindow, to: rootView)
        
//        // dont do rendercheck until we've scrolled a certain amount
//        if let lastRendered = self.lastRenderedWindow,
//            abs(lastRendered.origin.y - renderWindow.origin.y) < 50 {
//            return
//        }
        
        self.lastRenderedWindow = renderWindow
        
//        updateDebugWindowViews(in: renderWindow)
        
        if let renderedRootView = renderableRootNode.renderVisibleNodes(
            visibleRootViewWindow: renderWindow,
            didRender: { [weak self] renderableView, view in
                guard let self = self else { return }
                self.delegate?.viewDidRender(view: view, with: renderableView.viewProperties, in: self)
            },
            didUnrender: { [weak self] renderableView, view in
                guard let self = self else { return }
                self.delegate?.viewDidUnrender(view: view, with: renderableView.viewProperties, in: self)
        }) {
            rootView.addSubview(renderedRootView)
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
            
            return predicate(renderableView.renderedView, renderableView.viewProperties)
        }
        
        if let renderableNode = renderableViewNode {
            
            let renderedViews = renderableNode.renderAllChildNodes(didRender: { _, _ in }, didUnrender: { _, _ in })
            // make sure the view is rendered
            return (renderedViews, renderableNode.value.viewProperties)
        } else {
            return nil
        }
    }
}

struct ViewInteractionProperties {
    let tapCallback: ((UIView) -> Void)?
    let peekable: Bool
}

class RenderableView {
    let viewProperties: ViewProperties
    let localPosition: Point<Double>
    let dimensions: AbsoluteViewDimensions
    let absoluteTransform: CGAffineTransform // the sum of all the parent view's transformations. Includes the localPosition translation.
    let siblingIndex: Int // The index of this view in relation to its siblings
    let renderer: (RenderableView) -> UIView
    let interactionProperties: ViewInteractionProperties?
    
    fileprivate var renderedView: UIView? = nil
    
    init(
        viewProperties: ViewProperties,
        localPosition: Point<Double>,
        dimensions: AbsoluteViewDimensions,
        absoluteTransform: CGAffineTransform,
        siblingIndex: Int,
        renderer: @escaping (RenderableView) -> UIView,
        interactionProperties: ViewInteractionProperties?
        ) {
        self.viewProperties = viewProperties
        self.localPosition = localPosition
        self.dimensions = dimensions
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
        
//        // shows a visibility-box around the the view
//        if let rootView = parent.firstSuperview(where: { $0 is UIScrollView })?.subviews.first {
//            let debugView = UIView()
//            debugView.layer.borderColor = UIColor.red.withAlphaComponent(0.5).cgColor
//            debugView.layer.borderWidth = 1
//            debugView.isUserInteractionEnabled = false
//            rootView.addSubview(debugView)
//            debugView.frame = absoluteRect
//        }
        
        return view
    }
    
    func unrender() {
        renderedView?.removeFromSuperview()
        renderedView = nil
    }
    
    var absoluteRect: CGRect {
        return CGRect(origin: .zero, size: dimensions.size.cgSize)
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

extension TreeNode where T == (view: ViewProperties, dimensions: AbsoluteViewDimensions, position: Point<Double>) {
    func buildRenderableViewTree(rendererProperties: IncitoRenderer) -> TreeNode<RenderableView> {
        
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
        
        return self.mapValues { (nodeValues, newParent, index) in
            
            let (viewProperties, dimensions, localPosition) = nodeValues
            
            let parentSize = newParent?.value.dimensions.size ?? .zero
            let parentTransform = newParent?.value.absoluteTransform ?? .identity
            
            let localMove = CGAffineTransform.identity
                .translatedBy(x: CGFloat(localPosition.x),
                              y: CGFloat(localPosition.y))
            
            let transform = CGAffineTransform.identity
                .concatenating(dimensions.layout.transform.affineTransform)
                .concatenating(localMove)
                .concatenating(parentTransform)
            
            let renderer = buildViewRenderer(rendererProperties, viewType: viewProperties.type, parentSize: parentSize)
            
            return RenderableView(
                viewProperties: viewProperties,
                localPosition: localPosition,
                dimensions: dimensions,
                absoluteTransform: transform,
                siblingIndex: index,
                renderer: renderer,
                interactionProperties: interactionBuilder(viewProperties)
            )
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
                dimensions: renderableView.dimensions
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
            
            renderProperties.imageViewLoader(imgReq.url) {
                imgReq.completion($0)
            }
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
        
        // size the view
        
        // apply the style properties to the view
        let imageRequest = view.applyStyle(renderableView.viewProperties.style, dimensions: renderableView.dimensions, parentSize: parentSize)
        if let imgReq = imageRequest {
            renderProperties.imageViewLoader(imgReq.url) {
                imgReq.completion($0)
            }
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
        dimensions: AbsoluteViewDimensions
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
        
        label.backgroundColor = .clear
        
        // labels are vertically aligned in incito, so add to a container view
        container.insertSubview(label, at: 0)
        
        let containerInnerSize = dimensions.innerSize.cgSize
        let textHeight: CGFloat = {
            if let h = dimensions.intrinsicSize.height {
                return CGFloat(h)
            }
            // it may not have an intrinsic height calculated yet (eg. if the view container has absolute height specified)
            return ceil(label.sizeThatFits(CGSize(width: containerInnerSize.width, height: 0)).height)
        }()
        
        label.frame = CGRect(
            origin: CGPoint(
                x: dimensions.layout.padding.left,
                y: dimensions.layout.padding.top
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
        
        let imageLoadReq = ImageViewLoadRequest(url: imageProperties.source) { [weak container] loadedImageView in
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

extension UIView {
    func applyStyle(_ style: StyleProperties, dimensions: AbsoluteViewDimensions, parentSize: Size<Double>) -> ImageViewLoadRequest? {
        
        // apply the layout.view properties
        backgroundColor = style.backgroundColor?.uiColor ?? .clear
        clipsToBounds = style.clipsChildren
        
        var imageLoadReq: ImageViewLoadRequest? = nil
        if let bgImage = style.backgroundImage {
            imageLoadReq = ImageViewLoadRequest(url: bgImage.source) { [weak self] loadedImageView in
                guard let self = self else { return }
                
                if let imageView = loadedImageView {
                    imageView.contentMode = .scaleToFill
                    imageView.frame = self.bounds
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
            .concatenating(dimensions.layout.transform.affineTransform)
        
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
