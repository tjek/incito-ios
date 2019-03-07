//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

public final class RenderableView {
    let layout: ViewLayout
    let absoluteTransform: CGAffineTransform // the sum of all the parent view's transformations. Includes the localPosition translation.
    let siblingIndex: Int // The index of this view in relation to its siblings
    let renderer: (RenderableView) -> UIView
    let absoluteRect: CGRect
    
    fileprivate(set) var renderedView: UIView? = nil
    
    init(
        layout: ViewLayout,
        absoluteTransform: CGAffineTransform,
        siblingIndex: Int,
        renderer: @escaping (RenderableView) -> UIView
        ) {
        self.layout = layout
        self.absoluteTransform = absoluteTransform
        self.siblingIndex = siblingIndex
        self.renderer = renderer
        self.absoluteRect = CGRect(origin: .zero, size: layout.size.cgSize)
            .applying(absoluteTransform)
    }
    
    @discardableResult
    func render() -> UIView {
        if let view = renderedView {
            return view
        }
        
        let view = renderer(self)
        
        if layout.viewProperties.style.accessibility.isHidden {
            view.isAccessibilityElement = false
        } else if let a11yLbl = layout.viewProperties.style.accessibility.label {
            view.isAccessibilityElement = true
            view.accessibilityLabel = a11yLbl
        }
        
        self.renderedView = view
        view.tag = siblingIndex + 1 // add 1 so non-sibling subviews stay at the bottom
        
        return view
    }
    
    func unrender() {
        renderedView?.removeFromSuperview()
        renderedView = nil
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

typealias RenderableViewTree = TreeNode<RenderableView>

extension TreeNode where T == ViewLayout {
    func buildRenderableViewTree(rendererProperties: IncitoRenderer, nodeBuilt: (RenderableView) -> Void) -> RenderableViewTree {
        
        return self.mapValues { (viewLayout, newParent, index) in
            
            let viewProperties = viewLayout.viewProperties
            let localPosition = viewLayout.position
            
            let parentSize = newParent?.value.layout.size ?? .zero
            
            let parentTransform = newParent?.value.absoluteTransform ?? .identity
            
            let localMove = CGAffineTransform.identity
                .translatedBy(x: CGFloat(localPosition.x),
                              y: CGFloat(localPosition.y))
            
            let transform = CGAffineTransform.identity
                .concatenating(viewLayout.transform.affineTransform)
                .concatenating(localMove)
                .concatenating(parentTransform)
            
            let renderer = buildViewRenderer(rendererProperties, viewType: viewProperties.type, parentSize: parentSize)
            
            let renderableView = RenderableView(
                layout: viewLayout,
                absoluteTransform: transform,
                siblingIndex: index,
                renderer: renderer
            )
            
            nodeBuilt(renderableView)
            
            return renderableView
        }
    }
}

/// Builds a function that, when given a RenderableView, returns a UIView.
func buildViewRenderer(_ renderProperties: IncitoRenderer, viewType: ViewType, parentSize: Size<Double>) -> (RenderableView) -> UIView {
    
    let renderer: (RenderableView) -> UIView
    
    switch viewType {
    case let .text(textProperties):
        renderer = { renderableView in
            let container = RoundedShadowedView(renderableView: renderableView)
            
            // container must already have it's frame set correctly
            container.addTextView(
                textProperties: textProperties,
                fontProvider: renderProperties.fontProvider,
                textDefaults: renderProperties.theme?.textDefaults ?? .empty,
                padding: renderableView.layout.dimensions.layoutProperties.padding,
                intrinsicSize: renderableView.layout.dimensions.intrinsicSize
            )
            
            return container
        }
        
    case let .image(imageProperties):
        renderer = { renderableView in
            let container = RoundedShadowedView(renderableView: renderableView)
            
            // container must already have it's frame set correctly
            let imgReq = container.addImageView(
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
    case .video(let videoProperties):
        renderer = { renderableView in
            let container = RoundedShadowedView(renderableView: renderableView)
            
            // container must already have it's frame set correctly
            container.addVideoView(
                videoProperties: videoProperties
            )
            
            return container
        }
    case .videoEmbed(let videoProperties):
        renderer = { renderableView in
            let container = RoundedShadowedView(renderableView: renderableView)
            
            // container must already have it's frame set correctly
            container.addVideoEmbedView(
                videoProperties: videoProperties
            )
            
            return container
        }
    }
    
    return { renderableView in
        // this view must already have it's frame set
        let view = renderer(renderableView)
        
        // apply the style properties to the view
        let imageRequest = view.applyStyle(
            renderableView.layout.viewProperties.style
        )
        
        // perform any image loading
        if let imgReq = imageRequest {
            renderProperties.imageViewLoader(imgReq)
        }
        
        // apply the transform to the view
        view.setAnchorPoint(anchorPoint: CGPoint.zero)
        view.transform = view.transform
            .concatenating(renderableView.layout.transform.affineTransform)
        
        if view.transform.isIdentity == false {
            view.layer.allowsEdgeAntialiasing = true
        }
        
        return view
    }
}
