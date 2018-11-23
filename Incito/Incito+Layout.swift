//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

// MARK: -

struct Point { var x, y: Double }
struct Size { var width, height: Double }
struct Rect {
    var origin: Point
    var size: Size
}

extension Point {
    static let zero = Point(x: 0, y: 0)
}
extension Size {
    static let zero = Size(width: 0, height: 0)
}
extension Rect {
    static let zero = Rect(origin: .zero, size: .zero)
}

// MARK: -

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

extension Corners where Value == Unit {
    func absolute(in parent: Double) -> Corners<Double> {
        return .init(
            topLeft: topLeft.absolute(in: parent),
            topRight: topRight.absolute(in: parent),
            bottomLeft: bottomLeft.absolute(in: parent),
            bottomRight: bottomRight.absolute(in: parent)
        )
    }
}

struct AbsoluteLayoutProperties {
    var position: Edges<Double?>
    var margins: Edges<Double>
    var padding: Edges<Double>

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
    var rect: Rect
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
    default:
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
    
    let size = Size(
        width: width.clamped(min: absoluteLayout.minWidth, max: absoluteLayout.maxWidth),
        height: height.clamped(min: absoluteLayout.minHeight, max: absoluteLayout.maxHeight)
    )
    
    var childNodes: [LayoutNode] = []
    for childView in view.children {
        
        var childNode = layout(view: childView, parentLayout: .absolute, in: size)
        
        let childLayout = AbsoluteLayoutProperties(childView.layout, in: size)

        if let left = childLayout.position.left {
            childNode.rect.origin.x += left
        } else if let right = childLayout.position.right {
            childNode.rect.origin.x = size.width - right - childNode.rect.size.width
        } else {
            childNode.rect.origin.x = absoluteLayout.padding.left
        }
        
        if let top = childLayout.position.top {
            childNode.rect.origin.y += top
        } else if let bottom = childLayout.position.bottom {
            childNode.rect.origin.y = size.height - bottom - childNode.rect.size.height
        } else {
            childNode.rect.origin.y = absoluteLayout.padding.top
        }

        // TODO: apply margins & padding
        childNodes.append(childNode)
    }
    
    let rect = Rect(
        origin: .zero,
        size: size
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
        let constraintSize = Size(
            width: (absoluteLayout.width ?? parentSize.width) - absoluteLayout.padding.left - absoluteLayout.padding.right,
            height: (absoluteLayout.height ?? parentSize.height) - absoluteLayout.padding.top - absoluteLayout.padding.bottom
        )
        let contentSize = view.type.intrinsicSize(in: constraintSize)
        
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
            
            intrinsicSize = Size(
                width: width.clamped(min: absoluteLayout.minWidth, max: absoluteLayout.maxWidth),
                height: height.clamped(min: absoluteLayout.minHeight, max: absoluteLayout.maxHeight)
            )
        case .static:
            intrinsicSize = Size(
                width: (absoluteLayout.width ?? parentSize.width).clamped(min: absoluteLayout.minWidth, max: absoluteLayout.maxWidth),
                height: (absoluteLayout.height ?? contentSize.height).clamped(min: absoluteLayout.minHeight, max: absoluteLayout.maxHeight)
            )
        }
        
        size = intrinsicSize
    } else {
        // the size into which the children will try to fit.
        // subtracts the padding so they fit into a smaller space
        let fittingSize = Size(
            width: (absoluteLayout.width ?? parentSize.width).clamped(min: absoluteLayout.minWidth, max: absoluteLayout.maxWidth) - absoluteLayout.padding.left - absoluteLayout.padding.right,
            height: (absoluteLayout.height ?? parentSize.height).clamped(min: absoluteLayout.minHeight, max: absoluteLayout.maxHeight) - absoluteLayout.padding.left - absoluteLayout.padding.right
        )
        
        // stack all children vertically
        var originY = absoluteLayout.padding.top
        var maxChildWidth: Double = 0
        for childView in view.children {
            
            var childNode = layout(view: childView, parentLayout: .static, in: fittingSize)
            childNode.rect.origin.y += originY
            
            let childMargins = childView.layout.margins.absolute(in: fittingSize)
            
            childNodes.append(childNode)
            
            originY = childNode.rect.origin.y + childNode.rect.size.height + childMargins.bottom
            maxChildWidth = max(maxChildWidth, Double(childNode.rect.size.width) + childMargins.left + childMargins.right)
        }
        
        let totalChildHeight = originY + absoluteLayout.padding.bottom
        
        // use absolute size or fit to children
        size = Size(
            width: (absoluteLayout.width ?? maxChildWidth).clamped(min: absoluteLayout.minWidth, max: absoluteLayout.maxWidth),
            height: (absoluteLayout.height ?? Double(totalChildHeight)).clamped(min: absoluteLayout.minHeight, max: absoluteLayout.maxHeight)
        )
        
        // position the children horizontally now we know the size of the parent
        childNodes = childNodes.map {
            var childNode = $0
            
            switch view.layout.gravity {
            case .center?:
                childNode.rect.origin.x = (size.width / 2) - (childNode.rect.size.width / 2)
            case .right?:
                // TODO: padding/margins?
                childNode.rect.origin.x = size.width - absoluteLayout.padding.right - childNode.rect.size.width
                
            case .left?,
                 nil:
                // TODO: different depending on gravity. Defaults to no gravity (system LtR or RtL)
                
                childNode.rect.origin.x += absoluteLayout.padding.left
            }
            
            return childNode
        }
    }
    
    let rect = Rect(
        origin: Point( // TODO: move this to the parent
            x: absoluteLayout.margins.left,
            y: absoluteLayout.margins.top
        ),
        size: Size(
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

extension ViewType {
    func intrinsicSize(in constraintSize: Size) -> Size {
        switch self {
        case let .text(text):
            return sizeForText(text, maxWidth: constraintSize.width)
        default:
            return .zero
        }
    }
}

#if os(iOS)
import UIKit
func sizeForText(_ textProperties: TextViewProperties, maxWidth: Double) -> Size {
    
    let font = textProperties.font()
    
    let string = textProperties.text
    
    let boundingBox = string.boundingRect(
        with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
        options: .usesLineFragmentOrigin,
        attributes: [.font: font],
        context: nil)
    
    return Size(
        width: ceil(Double(boundingBox.size.width)),
        height: ceil(Double(boundingBox.size.height))
    )
}
#else
func sizeForText(_ textProperties: TextViewProperties, maxWidth: Double) -> Size {
    #error("sizeForText not implemented")
}
#endif
