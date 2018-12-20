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

class IncitoViewController: UIViewController {
    
    let scrollView = UIScrollView()
    
    let incitoDocument: Incito
    
    var rootView: UIView?
    var renderer: IncitoRenderer
    
    init(incito: Incito) {
        self.incitoDocument = incito
        self.renderer = IncitoRenderer(
            fontProvider: UIFont.systemFont(forFamily:size:),
            imageLoader: loadImage(url:completion:),
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

        queue.async { [weak self] in
            self?.loadFonts(fontAssets: fontAssets)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        renderVisibleViews()
    }
    
    
    let queue = DispatchQueue(label: "IncitoViewControllerQueue")
    
    func loadFonts(fontAssets: [FontAssetName: FontAsset]) {
        
        let fontLoader = FontAssetLoader.uiKitFontAssetLoader()
        
        let startFontLoad = Date.timeIntervalSinceReferenceDate
        fontLoader.loadAndRegisterFontAssets(fontAssets) { [weak self] (loadedAssets) in
            
            let endFontLoad = Date.timeIntervalSinceReferenceDate
            print(" ⇢ 🔠 Downloaded font assets: \(loadedAssets.count) in \(round((endFontLoad - startFontLoad) * 1_000))ms")
            loadedAssets.forEach { asset in
                print("    ‣ '\(asset.assetName)': \(asset.fontName)")
            }
            
            DispatchQueue.main.async { [weak self] in
                
                // update the renderer's fontProvider
                self?.renderer.fontProvider = loadedAssets.font(forFamily:size:)
                
                // build complete layout
                self?.buildLayout()
            }
        }
    }
    
    // must call from main
    func buildLayout() {
        
        let rootIncitoView: ViewNode = incitoDocument.rootView
        let fontProvider = self.renderer.fontProvider
        let defaultTextProperties = incitoDocument.theme?.textDefaults ?? .empty
        let parentSize = Size(cgSize: self.view.frame.size)

        let start = Date.timeIntervalSinceReferenceDate
        
        let layouterTree = generateLayouters(
            rootNode: rootIncitoView,
            layoutType: .block,
            intrinsicViewSizer: uiKitViewSizer(fontProvider, defaultTextProperties)
        )
        
        let dimensionsTree = resolveLayouters(
            rootNode: layouterTree,
            rootSize: parentSize
        )
        
        self.renderableTree = buildRenderableViewTree(dimensionsTree, rendererProperties: self.renderer)
        
        // build the layout
//        let rootLayoutNode = LayoutNode.build(
//            rootView: rootIncitoView,
//            intrinsicSize: uiKitViewSizer(fontProvider, defaultTextProperties),
//            in: parentSize
//        )
        
        let end = Date.timeIntervalSinceReferenceDate
        print(" ⇢ 🚧 Built layout graph: \(round((end - start) * 1_000))ms")
        
        let debugTree = dimensionsTree.mapValues { value, _ in
            "\(value.view.id ?? "?"): [ size \(value.dimensions.size), pos \(value.position), margins \(value.dimensions.layout.margins), padding \(value.dimensions.layout.padding) ]"
        }
        
        print("\(debugTree)")
        
        DispatchQueue.main.async { [weak self] in
            self?.initializeRootView(parentSize: parentSize.cgSize)
//            self?.initializeRootView(dimensionsTree: dimensionsTree, in: parentSize)
//            self?.initializeRootView(rootLayoutNode: rootLayoutNode)
        }
    }
    
    var renderableTree: TreeNode<RenderableView>? = nil
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
//    func initializeRootView(dimensionsTree: TreeNode<(view: ViewProperties, dimensions: AbsoluteViewDimensions, position: Point<Double>)>, in parentSize: Size<Double>) {
//
//        let rootView = dimensionsTree.buildViews(textViewDefaults: incitoDocument.theme?.textDefaults ?? .empty, fontProvider: self.renderer.fontProvider)
//
//        let wrapper = UIView()
//        wrapper.addSubview(rootView)
//        scrollView.insertSubview(wrapper, at: 0)
//
//        wrapper.translatesAutoresizingMaskIntoConstraints = false
//        NSLayoutConstraint.activate([
//            wrapper.topAnchor.constraint(equalTo: scrollView.topAnchor),
//            wrapper.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
//            wrapper.leftAnchor.constraint(greaterThanOrEqualTo: scrollView.leftAnchor),
//            wrapper.rightAnchor.constraint(lessThanOrEqualTo: scrollView.rightAnchor),
//            wrapper.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
//
//            wrapper.heightAnchor.constraint(equalToConstant: CGFloat(parentSize.height)),
//            wrapper.widthAnchor.constraint(equalToConstant: CGFloat(parentSize.width))
//            ])
//
//    }
    
//    func initializeRootView(rootLayoutNode: LayoutNode) {
//
//
//        self.rootLayoutNode = rootLayoutNode
//
//        // TODO: Load the imageReqs for the rootview
//        // build (just) the rootView
//        let (rootView, imageReqs) = UIView.build(rootLayoutNode,
//                                    renderer: self.renderer,
//                                    maxDepth: 0)
//
//        self.rootView = rootView
//
//        let viewBuilder = viewHierarchyBuilder(self.renderer)
//
//        self.renderableSections = rootLayoutNode.children.map {
//            RenderableSection(
//                layoutNode: $0,
//                viewBuilder: viewBuilder,
//                imageLoader: renderer.imageLoader
//            )
//        }
//
//        let wrapper = UIView()
//        wrapper.addSubview(rootView)
//        scrollView.insertSubview(wrapper, at: 0)
//
//        wrapper.translatesAutoresizingMaskIntoConstraints = false
//        NSLayoutConstraint.activate([
//            wrapper.topAnchor.constraint(equalTo: scrollView.topAnchor),
//            wrapper.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
//            wrapper.leftAnchor.constraint(greaterThanOrEqualTo: scrollView.leftAnchor),
//            wrapper.rightAnchor.constraint(lessThanOrEqualTo: scrollView.rightAnchor),
//            wrapper.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
//
//            wrapper.heightAnchor.constraint(equalToConstant: rootView.frame.size.height),
//            wrapper.widthAnchor.constraint(equalToConstant: rootView.frame.size.width)
//            ])
//
//        renderVisibleSections()
//    }
    
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
                        .inset(by: UIEdgeInsets(top: 120, left: 0, bottom: 150, right: 0))
//            .inset(by: UIEdgeInsets(top: -200, left: 0, bottom: -400, right: 0))

        // in RootView coord space
        let renderWindow = scrollView.convert(scrollVisibleWindow, to: rootView)
        
//        // dont do rendercheck until we've scrolled a certain amount
//        if let lastRendered = self.lastRenderedWindow,
//            abs(lastRendered.origin.y - renderWindow.origin.y) < 50 {
//            return
//        }
        
        self.lastRenderedWindow = renderWindow
        
        updateDebugWindowViews(in: renderWindow)
        
        renderVisibleNodes(rootNode: renderableRootNode,
                           visibleRootViewWindow: renderWindow,
                           parentView: rootView)
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

//    func renderVisibleSections() {
//        return
//        guard let rootView = self.rootView else {
//            return
//        }
//
//        // TODO: this is DEBUG to make lazy loading obvious
//        let scrollVisibleWindow = scrollView.bounds
////            .inset(by: UIEdgeInsets(top: 200, left: 0, bottom: 200, right: 0))
//            .inset(by: UIEdgeInsets(top: -200, left: 0, bottom: -400, right: 0))
//
//        let renderWindow = scrollView.convert(scrollVisibleWindow, to: rootView)
//
//        // dont do rendercheck until we've scrolled a certain amount
//        if let lastRendered = self.lastRenderedWindow,
//            abs(lastRendered.origin.y - renderWindow.origin.y) < 50 {
//            return
//        }
//
//        self.lastRenderedWindow = renderWindow
//
//        for renderableSection in renderableSections {
//            // just render all of them
//            //            renderableSection.render(into: rootView)
//
//            if renderWindow.intersects(renderableSection.layoutNode.rect.cgRect) {
//                renderableSection.render(into: rootView)
//            } else {
//                // TODO: only unrender on memory pressure or if rendered section count gets large
//                renderableSection.unrender()
//            }
//        }
//    }
}
extension IncitoViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        renderVisibleViews()
    }
}

func unrenderChildNodes(rootNode: TreeNode<RenderableView>) {
    rootNode.forEachNode(rootFirst: true) { (node, _, _) in
        node.value.unrender()
    }
}

func renderVisibleNodes(rootNode: TreeNode<RenderableView>, visibleRootViewWindow: CGRect, parentView: UIView) {
    
    let absoluteRect = rootNode.value.absoluteRect
    
    // TODO: if it doesnt clip, build from sum of all children, incase the children are larger than the node?
    
    guard visibleRootViewWindow.intersects(absoluteRect) else {
        unrenderChildNodes(rootNode: rootNode)
        return
    }
    
    let renderedView = rootNode.value.render(into: parentView)
    
    for childNode in rootNode.children {
        renderVisibleNodes(rootNode: childNode, visibleRootViewWindow: visibleRootViewWindow, parentView: renderedView)
    }
}


///// Given a renderer it will return a ViewBuilder that builds the entire view hierarchy.
//let viewHierarchyBuilder: (IncitoRenderer) -> (LayoutNode) -> (UIView, [ImageLoadRequest]) = { renderer in
//    return { layoutNode in
//        return UIView.build(layoutNode, renderer: renderer, depth: 0, maxDepth: nil)
//    }
//}
//
//class RenderableSection {
//    let layoutNode: LayoutNode
//    let viewBuilder: (LayoutNode) -> (UIView, [ImageLoadRequest])
//    let imageLoader: ImageLoader
//
//    var renderedView: UIView? = nil
////    var pendingImageLoadRequests: [ImageLoadRequest] = []
//
//    init(layoutNode: LayoutNode, viewBuilder: @escaping (LayoutNode) -> (UIView, [ImageLoadRequest]), imageLoader: @escaping ImageLoader) {
//        self.layoutNode = layoutNode
//        self.viewBuilder = viewBuilder
//        self.imageLoader = imageLoader
//    }
//
//    func unrender() {
//        self.renderedView?.removeFromSuperview()
//        self.renderedView = nil
//    }
//
//    func render(into parentView: UIView) {
//        // TODO: a 'force' option to refresh the view?
//        guard renderedView == nil else {
//            return
//        }
//
//        let (view, imgReqs) = self.viewBuilder(self.layoutNode)
//        self.renderedView = view
//
//        parentView.addSubview(view)
//
//        print(" ⇢ 🎨 Lazily Rendering Section (\(imgReqs.count) images)", self.layoutNode.rect.origin)
//
//        // TODO: some kind of cancellation strategy
////        self.pendingImageLoadRequests = imgReqs
//
//        let start = Date.timeIntervalSinceReferenceDate
//
//        let pendingReqCount = imgReqs.count
//        var completedReqs: (success: Int, err: Int) = (0, 0)
//        for req in imgReqs {
//            self.imageLoader(req.url) {
//                req.completion($0)
//
//                if $0 == nil {
//                    completedReqs.err += 1
//                } else {
//                    completedReqs.success += 1
//                }
//
//                if (completedReqs.err + completedReqs.success) == pendingReqCount {
//
//
//                    let end = Date.timeIntervalSinceReferenceDate
//
//                    print("    ‣ Images loaded: \(pendingReqCount) images in \(round((end - start) * 1_000))ms (\(completedReqs.success)x ✅,  \(completedReqs.err)x ❌)")
//                }
//            }
//        }
//    }
//}

extension UIView {
    
    static func buildTextView(_ textProperties: TextViewProperties, textDefaults: TextViewDefaultProperties, styleProperties: StyleProperties, fontProvider: FontProvider, position: Point<Double>, dimensions: AbsoluteViewDimensions) -> UIView {
        
        let label = UILabel()
        
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
        let container = UIView()
        container.frame = CGRect(origin: .zero,
                                 size: dimensions.size.cgSize)
        
        container.addSubview(label)
        
        let textHeight = label.sizeThatFits(container.bounds.size).height
        label.frame = CGRect(origin: CGPoint(x: dimensions.layout.padding.left, y: dimensions.layout.padding.top),
                             size: CGSize(width: CGFloat(dimensions.innerSize.width),
                                          height: textHeight))
        label.autoresizingMask = [.flexibleBottomMargin, .flexibleWidth]
        
        label.textColor = .black
        
        return container
    }
}

struct RenderableView {
    let viewProperties: ViewProperties
    let localPosition: Point<Double>
    let dimensions: AbsoluteViewDimensions
    let absoluteTransform: CGAffineTransform // the sum of all the parent view's transformations. Includes the localPosition translation.
    
    let render: (RenderableView) -> UIView
    // TODO: add tap callback?
    
    private var renderedView: UIView? = nil
    
    init(
        viewProperties: ViewProperties,
        localPosition: Point<Double>,
        dimensions: AbsoluteViewDimensions,
        absoluteTransform: CGAffineTransform,
        render: @escaping (RenderableView) -> UIView
        ) {
        self.viewProperties = viewProperties
        self.localPosition = localPosition
        self.dimensions = dimensions
        self.absoluteTransform = absoluteTransform
        self.render = render
    }
    
    @discardableResult
    mutating func render(into parent: UIView) -> UIView {
        if let view = renderedView {
            return view
        }
        
        let view = render(self)
        
        self.renderedView = view
        parent.addSubview(view)

//        if let rootView = parent.firstSuperview(where: { $0 is UIScrollView })?.subviews.first {
//
//            // shows a visibility-box around the the view
//            let debugView = UIView()
//            debugView.layer.borderColor = UIColor.red.withAlphaComponent(0.5).cgColor
//            debugView.layer.borderWidth = 1
//            debugView.isUserInteractionEnabled = false
//            rootView.addSubview(debugView)
//            debugView.frame = absoluteRect
//        }
        
        return view
    }
    
    mutating func unrender() {
        renderedView?.removeFromSuperview()
        renderedView = nil
    }
    
    var absoluteRect: CGRect {
        return CGRect(origin: .zero, size: dimensions.size.cgSize)
            .applying(absoluteTransform)
    }
}

func buildRenderableViewTree(_ root: TreeNode<(view: ViewProperties, dimensions: AbsoluteViewDimensions, position: Point<Double>)>, rendererProperties: IncitoRenderer) -> TreeNode<RenderableView> {
    
    return root.mapValues { (nodeValues, newParent) in
        
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
            render: renderer
        )
    }
}

func buildViewRenderer(_ renderProperties: IncitoRenderer, viewType: ViewType, parentSize: Size<Double>) -> (RenderableView) -> UIView {
    
    let renderer: (RenderableView) -> UIView
    
    switch viewType {
    case let .text(textProperties):
        renderer = { renderableView in
            return .buildTextView(
                textProperties: textProperties,
                fontProvider: renderProperties.fontProvider,
                textDefaults: renderProperties.theme?.textDefaults ?? .empty,
                dimensions: renderableView.dimensions
            )
        }
        
    case let .image(imageProperties):
        renderer = { renderableView in
            let (imgView, imgReq) = UIView.buildImageView(
                imageProperties: imageProperties,
                styleProperties: renderableView.viewProperties.style,
                dimensions: renderableView.dimensions
            )
            //        imageLoadRequests.append(imgReq)
            renderProperties.imageLoader(imgReq.url) {
                imgReq.completion($0)
            }
            return imgView
        }
    case .view,
         .absoluteLayout,
         .flexLayout:
        renderer = { _ in .buildEmptyView() }
    default:
        renderer = { renderableView in
            let view = UIView()
            return view
        }
    }
    
    return { renderableView in
        let view = renderer(renderableView)
        
        // size the view
        view.frame = CGRect(origin: renderableView.localPosition.cgPoint,
                            size: renderableView.dimensions.size.cgSize)
        
        // apply the style properties to the view
        view.applyStyle(renderableView.viewProperties.style, dimensions: renderableView.dimensions, parentSize: parentSize)
        
        return view
    }
}

extension UIView {
    
    static func buildTextView(
        textProperties: TextViewProperties,
        fontProvider: FontProvider,
        textDefaults: TextViewDefaultProperties,
        dimensions: AbsoluteViewDimensions
        ) -> UIView {
        
        let label = UILabel()
        
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
        let container = UIView()
        container.addSubview(label)
        
        let containerInnerSize = dimensions.innerSize.cgSize
        let textHeight: CGFloat = {
            if let h = dimensions.intrinsicSize.height {
                return CGFloat(h)
            }
            
            return label.sizeThatFits(CGSize(width: containerInnerSize.width, height: 0)).height
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
        
        return container
    }
    
    static func buildEmptyView() -> UIView {
        return UIView()
    }
    
    static func buildImageView(
        imageProperties: ImageViewProperties,
        styleProperties: StyleProperties,
        dimensions: AbsoluteViewDimensions
        ) -> (UIView, ImageLoadRequest) {
        
        let imageView = UIImageView()
        imageView.contentMode = .scaleToFill
        
        let imageLoadReq = ImageLoadRequest(url: imageProperties.source) { [weak imageView] loadedImage in
            
            guard let imgView = imageView else { return }
            
            UIView.transition(
                with: imgView,
                duration: 0.2,
                options: .transitionCrossDissolve,
                animations: {
                    if let img = loadedImage {
                        imgView.image = img
                    } else {
                        imgView.backgroundColor = .red
                    }            },
                completion: nil
            )
        }
        
        return (imageView, imageLoadReq)
    }
}

extension UIView {
    func applyStyle(_ style: StyleProperties, dimensions: AbsoluteViewDimensions, parentSize: Size<Double>) {
        
        // apply the layout.view properties
        backgroundColor = style.backgroundColor?.uiColor ?? .clear
        clipsToBounds = style.clipsChildren
        
        // Use the smallest dimension when calculating relative corners.
        let cornerRadius = style.cornerRadius.absolute(in: min(dimensions.size.width, dimensions.size.height) / 2)
        
        // only mask the view if it has rounded corners
        if cornerRadius != Corners<Double>.zero {
            if cornerRadius.topLeft == cornerRadius.topRight && cornerRadius.bottomLeft == cornerRadius.bottomRight &&
                cornerRadius.topLeft == cornerRadius.bottomLeft {
                
                layer.cornerRadius = CGFloat(cornerRadius.topLeft)
            } else {
                roundCorners(
                    topLeft: CGFloat(cornerRadius.topLeft),
                    topRight: CGFloat(cornerRadius.topRight),
                    bottomLeft: CGFloat(cornerRadius.bottomLeft),
                    bottomRight: CGFloat(cornerRadius.bottomRight)
                )
            }
        }
        
        
        // TODO: use real anchor point
        setAnchorPoint(anchorPoint: CGPoint.zero)
        
        self.transform = self.transform
            .concatenating(dimensions.layout.transform.affineTransform)
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
