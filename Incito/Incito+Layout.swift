//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation
import UIKit

enum ViewType {
    case view
    case absoluteLayout
    case text(String)
}

struct StyleProperties {
    // ...
    // cornerRadius etc
    
    var backgroundColor: Color?
}

struct LayoutProperties {
    var position: Edges<Unit?>
    var padding: UnitEdges
    var margins: UnitEdges
    
    var height: LayoutSize?
    var width: LayoutSize?
    var minHeight: Unit?
    var minWidth: Unit?
    var maxHeight: Unit?
    var maxWidth: Unit?
    
    var gravity: HorizontalGravity? // is this inherited?
}

struct View {
    var type: ViewType
    var style: StyleProperties
    
    var id: String?
    
    var layout: LayoutProperties
    var children: [View]
}

// MARK: -

typealias Size = (width: Double, height: Double)
typealias AbsEdges = Edges<Double>

extension Unit {
    func absolute(in parent: Double) -> Double {
        switch self {
        case let .pts(pts):
            return pts
        case let .percent(pct):
            return parent * pct
        }
    }
}

extension LayoutSize {
    func absolute(in parentSize: Double) -> Double? {
        switch self {
        case .wrapContent:
            return nil
        case .matchParent:
            return parentSize
        case let .unit(unit):
            return unit.absolute(in: parentSize)
        }
    }
}

extension Edges where Value == Unit {
    func absolute(in parent: Size) -> Edges<Double> {
        return .init(
            top: self.top.absolute(in: parent.height),
            left: self.left.absolute(in: parent.width),
            bottom: self.bottom.absolute(in: parent.height),
            right: self.right.absolute(in: parent.width)
        )
    }
}
extension Edges where Value == Unit? {
    func absolute(in parent: Size) -> Edges<Double?> {
        return .init(
            top: self.top?.absolute(in: parent.height),
            left: self.left?.absolute(in: parent.width),
            bottom: self.bottom?.absolute(in: parent.height),
            right: self.right?.absolute(in: parent.width)
        )
    }
}

struct AbsoluteLayoutProperties {
    var position: Edges<Double?>
    var margins: AbsEdges
    var padding: AbsEdges

    var maxWidth: Double
    var minWidth: Double
    var maxHeight: Double
    var minHeight: Double

    var height: Double? // nil if fitting to child
    var width: Double? // nil if fitting to child
}

extension AbsoluteLayoutProperties {
    init(_ properties: LayoutProperties, in parentSize: Size) {
        self.maxWidth = properties.maxWidth?.absolute(in: parentSize.width) ?? .infinity
        self.minWidth = properties.minWidth?.absolute(in: parentSize.width) ?? 0
        self.maxHeight = properties.maxHeight?.absolute(in: parentSize.height) ?? .infinity
        self.minHeight = properties.minHeight?.absolute(in: parentSize.height) ?? 0
        
        self.height = (properties.height ?? .wrapContent).absolute(in: parentSize.height)
        self.width = (properties.width ?? .matchParent).absolute(in: parentSize.width)
        
        self.position = properties.position.absolute(in: parentSize)
        self.margins = properties.margins.absolute(in: parentSize)
        self.padding = properties.padding.absolute(in: parentSize)
    }
}

extension Double {
    func clamped(min: Double, max: Double) -> Double {
        return Swift.min(Swift.max(self, min), max)
    }
}

struct LayoutNode {
    var view: (id: String?, type: ViewType, style: StyleProperties)
    var rect: CGRect
    var children: [LayoutNode]
}

enum LayoutType {
    case `static`
    case absolute
}

func layout(view: View, parentLayout: LayoutType, in parentSize: Size) -> LayoutNode {
    switch view.type {
    case .view:
        return staticLayout(view: view, parentLayout: parentLayout, in: parentSize)
    case .absoluteLayout:
        return absoluteLayout(view: view, parentLayout: parentLayout, in: parentSize)
    case .text(_):
        return staticLayout(view: view, parentLayout: parentLayout, in: parentSize)
    }
}

// MARK: - Absolute Layout

func absoluteLayout(view: View, parentLayout: LayoutType, in parentSize: Size) -> LayoutNode {
    
    // make absolute versions of the layout properties based on the parentSize
    let absoluteLayout = AbsoluteLayoutProperties(view.layout, in: parentSize)

    let width: Double = {
        guard let w = absoluteLayout.width else {
            return parentSize.width
        }
        return w + absoluteLayout.padding.left + absoluteLayout.padding.right
    }()
    let height: Double = {
        return (absoluteLayout.height ?? 0) + absoluteLayout.padding.top + absoluteLayout.padding.bottom
    }()
    
    let size: Size = (
        width: width.clamped(min: absoluteLayout.minWidth, max: absoluteLayout.maxWidth),
        height: height.clamped(min: absoluteLayout.minHeight, max: absoluteLayout.maxHeight)
    )
    
    var childNodes: [LayoutNode] = []
    for childView in view.children {
        
        var childNode = layout(view: childView, parentLayout: .absolute, in: size)
        
        let childLayout = AbsoluteLayoutProperties(childView.layout, in: size)

        if let left = childLayout.position.left {
            childNode.rect.origin.x += CGFloat(left)
        } else if let right = childLayout.position.right {
            childNode.rect.origin.x = CGFloat(size.width - right) - childNode.rect.width
        } else {
            childNode.rect.origin.x = CGFloat(absoluteLayout.padding.left)
        }
        
        if let top = childLayout.position.top {
            childNode.rect.origin.y += CGFloat(top)
        } else if let bottom = childLayout.position.bottom {
            childNode.rect.origin.y = CGFloat(size.height - bottom) - childNode.rect.height
        } else {
            childNode.rect.origin.y = CGFloat(absoluteLayout.padding.top)
        }

        // TODO: apply margins & padding
        childNodes.append(childNode)
    }
    
    let rect = CGRect(
        origin: .zero,
        size: CGSize(
            width: CGFloat(size.width),
            height: CGFloat(size.height)
        )
    )
    
    return LayoutNode(
        view: (view.id, view.type, view.style),
        rect: rect,
        children: childNodes
    )
}

// MARK: - Static Layout

/// Generate a LayoutNode for a View and it's children, fitting inside parentSize.
/// The LayoutNode's rect is sized, and it's children positioned, but it's origin is not modified eg. it's margin is not taken into account (that is the job of the parent node's layout method)
func staticLayout(view: View, parentLayout: LayoutType, in parentSize: Size) -> LayoutNode {
    
    // make absolute versions of the layout properties based on the parentSize
    let absoluteLayout = AbsoluteLayoutProperties(view.layout, in: parentSize)
    
    var childNodes: [LayoutNode] = []
    let size: Size
    
    if view.children.isEmpty {
        // no children: get the intrinsic content size
        
        // TODO: build intrinsicSize from the view-type itself
        let contentSize: Size = (width: 0, height: 0)
        
        let intrinsicSize: Size
//        let defaultHeight: Double = 30 // the height of a view that doesnt have any intrinsic height
//        let intrinsicSize: Size = (
//            width: (absoluteLayout.width ?? parentSize.width).clamped(min: absoluteLayout.minWidth, max: absoluteLayout.maxWidth),
//            height: (absoluteLayout.height ?? defaultHeight).clamped(min: absoluteLayout.minHeight, max: absoluteLayout.maxHeight)
//        )
        
        
        switch parentLayout {
        case .absolute:
            // if the parent is absolute, then dont make 100% wide by default. Instead use the left/right etc properties if available

            // TODO: padding?
            let width: Double = {
                if view.layout.width != nil, let w = absoluteLayout.width {
                    // if a specific width is provided, just use that.
                    return w
                } else if let left = absoluteLayout.position.left,
                    let right = absoluteLayout.position.right {
                    // if there are specific left & right then subtract them from parent width
                    return parentSize.width - left - right
                } else {
                    // otherwise just use the content's size
                    return contentSize.width
                }
            }()
            
            let height: Double = {
                if let h = absoluteLayout.height {
                    // if a specific height is provided, just use that.
                    return h
                } else if let top = absoluteLayout.position.top,
                    let bottom = absoluteLayout.position.bottom {
                    // if there are specific top & bottom then subtract them from parent height
                    return parentSize.height - top - bottom
                } else {
                    // otherwise just use the content's size
                    return contentSize.height
                }
            }()
            
            intrinsicSize = (
                width: width.clamped(min: absoluteLayout.minWidth, max: absoluteLayout.maxWidth),
                height: height.clamped(min: absoluteLayout.minHeight, max: absoluteLayout.maxHeight)
            )
        case .static:
            intrinsicSize = (
                width: (absoluteLayout.width ?? parentSize.width).clamped(min: absoluteLayout.minWidth, max: absoluteLayout.maxWidth),
                height: (absoluteLayout.height ?? contentSize.height).clamped(min: absoluteLayout.minHeight, max: absoluteLayout.maxHeight)
            )
        }
        
        size = intrinsicSize
    } else {
        // the size into which the children will try to fit.
        // subtracts the padding so they fit into a smaller space
        let fittingSize: Size = (
            width: (absoluteLayout.width ?? parentSize.width).clamped(min: absoluteLayout.minWidth, max: absoluteLayout.maxWidth) - absoluteLayout.padding.left - absoluteLayout.padding.right,
            height: (absoluteLayout.height ?? parentSize.height).clamped(min: absoluteLayout.minHeight, max: absoluteLayout.maxHeight) - absoluteLayout.padding.left - absoluteLayout.padding.right
        )
        
        // stack all children vertically
        var originY: CGFloat = CGFloat(absoluteLayout.padding.top)
        var maxChildWidth: Double = 0
        for childView in view.children {
            
            var childNode = layout(view: childView, parentLayout: .static, in: fittingSize)
            childNode.rect.origin.y += originY
            
            let childMargins: AbsEdges = childView.layout.margins.absolute(in: fittingSize)
            
            childNodes.append(childNode)
            
            originY = childNode.rect.maxY + CGFloat(childMargins.bottom)
            maxChildWidth = max(maxChildWidth, Double(childNode.rect.size.width) + childMargins.left + childMargins.right)
        }
        
        let totalChildHeight = originY + CGFloat(absoluteLayout.padding.bottom)
        
        // use absolute size or fit to children
        size = (
            width: (absoluteLayout.width ?? maxChildWidth).clamped(min: absoluteLayout.minWidth, max: absoluteLayout.maxWidth),
            height: (absoluteLayout.height ?? Double(totalChildHeight)).clamped(min: absoluteLayout.minHeight, max: absoluteLayout.maxHeight)
        )
        
        // position the children horizontally now we know the size of the parent
        childNodes = childNodes.map {
            var childNode = $0
            
            switch view.layout.gravity {
            case .center?:
                childNode.rect.origin.x = (CGFloat(size.width) / 2) - (childNode.rect.width / 2)
            case .right?:
                // TODO: padding/margins?
                childNode.rect.origin.x = CGFloat(size.width - absoluteLayout.padding.right) - childNode.rect.size.width
                
            case .left?,
                 nil:
                // TODO: different depending on gravity. Defaults to no gravity (system LtR or RtL)
                
                childNode.rect.origin.x += CGFloat(absoluteLayout.padding.left)
            }
            
            return childNode
        }
    }
    
    let rect = CGRect(
        origin: CGPoint(
            x: absoluteLayout.margins.left,
            y: absoluteLayout.margins.top
        ),
        size: CGSize(
            width: size.width,
            height: size.height
        )
    )
    
    return LayoutNode(
        view: (view.id, view.type, view.style),
        rect: rect,
        children: childNodes
    )
}

// MARK: - Debug Mapping

// Quick dummy mapping, until we change the shape of the Incito
extension IncitoViewType {
    var view: View {
        
        let viewType: ViewType = {
            switch self {
            case .view:
                return .view
            case .absoluteLayout:
                return .absoluteLayout
            case let .textView(textProperties, _):
                return .text(textProperties.text)
            default:
                return .view //TODO
            }
        }()
        
        let style = StyleProperties(
            backgroundColor: self.viewProperties.backgroundColor
        ) // TODO
        
        let id = viewProperties.id
        
        let layout: LayoutProperties = {
            let props = self.viewProperties
            
            return LayoutProperties(
                position: props.position,
                padding: props.padding,
                margins: props.margins,
                height: props.height,
                width: props.width,
                minHeight: props.minHeight,
                minWidth: props.minWidth,
                maxHeight: props.maxHeight,
                maxWidth: props.minWidth,
                gravity: props.gravity)
        }()
        
        let children = self.viewProperties.childViews.map({ $0.view })
        
        return View(
            type: viewType,
            style: style,
            id: id,
            layout: layout,
            children: children
        )
    }
}
