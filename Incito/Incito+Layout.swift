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
    var layout: UnitEdges?
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
typealias Edges = (top: Double, left: Double, bottom: Double, right: Double)

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

extension UnitEdges {
    func absolute(in parent: Size) -> Edges {
        return (
            top: self.top.absolute(in: parent.height),
            left: self.left.absolute(in: parent.width),
            bottom: self.bottom.absolute(in: parent.height),
            right: self.right.absolute(in: parent.width)
        )
    }
}

struct AbsoluteLayoutProperties {
    var margins: Edges
    var padding: Edges

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

func layout(view: View, in parentSize: Size) -> LayoutNode {
    // TODO: pick layout based on view type
    return staticLayout(view: view, in: parentSize)
}

// MARK: - Static Layout

/// Generate a LayoutNode for a View and it's children, fitting inside parentSize.
/// The LayoutNode's rect is sized, and it's children positioned, but it's origin is not modified eg. it's margin is not taken into account (that is the job of the parent node's layout method)
func staticLayout(view: View, in parentSize: Size) -> LayoutNode {
    
    // make absolute versions of the layout properties based on the parentSize
    let absoluteLayout = AbsoluteLayoutProperties(view.layout, in: parentSize)
    
    var childNodes: [LayoutNode] = []
    let size: Size
    
    if view.children.isEmpty {
        // no children: get the intrinsic content size
        
        // TODO: build intrinsicSize from the view-type itself
        let defaultHeight: Double = 30 // the height of a view that doesnt have any intrinsic height
        let intrinsicSize: Size = (
            width: (absoluteLayout.width ?? parentSize.width).clamped(min: absoluteLayout.minWidth, max: absoluteLayout.maxWidth),
            height: (absoluteLayout.height ?? defaultHeight).clamped(min: absoluteLayout.minHeight, max: absoluteLayout.maxHeight)
        )
            
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
            
            var childNode = layout(view: childView, in: fittingSize)
            childNode.rect.origin.y += originY
            
            let childMargins: Edges = childView.layout.margins.absolute(in: fittingSize)
            
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
            
            // TODO: different depending on gravity. Defaults to no gravity (system LtR or RtL)
            // center
//            childNode.rect.origin.x = (CGFloat(size.width) / 2) - (childNode.rect.width / 2)
            
            // left aligned
            childNode.rect.origin.x += CGFloat(absoluteLayout.padding.left)
            
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
                layout: props.layout,
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
