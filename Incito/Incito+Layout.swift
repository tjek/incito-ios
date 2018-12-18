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
    /// parentSize is the container's inner size (size - padding)
    init(_ properties: LayoutProperties, in parentSize: Size<Double>) {
        self.maxWidth = properties.maxWidth?.absolute(in: parentSize.width) ?? .infinity
        self.minWidth = properties.minWidth?.absolute(in: parentSize.width) ?? 0
        self.maxHeight = properties.maxHeight?.absolute(in: parentSize.height) ?? .infinity
        self.minHeight = properties.minHeight?.absolute(in: parentSize.height) ?? 0
        
        self.height = properties.height?.absolute(in: parentSize.height)
        self.width = properties.width?.absolute(in: parentSize.width)
        
        self.position = properties.position.absolute(in: parentSize)
        
        // margins & padding are actually only relative to the width of the parent, not the height
        let squareParentSize = Size(width: parentSize.width, height: parentSize.width)
        self.margins = properties.margins.absolute(in: squareParentSize)
        self.padding = properties.padding.absolute(in: squareParentSize)
    }
}

extension Double {
    func clamped(min: Double, max: Double) -> Double {
        return Swift.min(Swift.max(self, min), max)
    }
}

struct LayoutNode {
    var view: (id: String?, type: ViewType, style: StyleProperties)
    var rect: Rect<Double>
    var children: [LayoutNode]
}

//extension LayoutNode {
//    static func build(
//        view: ViewNode,
//        intrinsicSizer: ViewSizer,
//        layoutType: LayoutType,
//        containerSize: Size<Double>,
//        containerPadding: Edges<Double>
//        ) -> LayoutNode {
//
//        let node: LayoutNode
//
//        // based on the viewType we decide how we are going position & size a node's children.
//        switch view.value.type {
//        case .absoluteLayout:
//            node = absoluteLayout(
//                view: view,
//                intrinsicSizer: intrinsicSizer,
//                layoutType: layoutType,
//                containerSize: containerSize,
//                containerPadding: containerPadding
//            )
//
////        case .flexLayout(let flexProperties):
////            node = flexLayout(
////                view: view,
////                flex: flexProperties,
////                leafSizer: leafSizer,
////                parentLayout: parentLayout,
////                in: containerInnerSize,
////                sizeConstraints: sizeConstraints
////            )
//
//        case .view:
//            fallthrough
//        default:
//            node = staticLayout(
//                view: view,
//                intrinsicSizer: intrinsicSizer,
//                layoutType: layoutType,
//                containerSize: containerSize,
//                containerPadding: containerPadding
//            )
//        }
//
//        return node
//    }
//
//    static func build(rootView: ViewNode, leafSizer: ViewSizer, in containerSize: Size<Double>) -> LayoutNode {
//        return .build(view: rootView, intrinsicSizer: leafSizer, layoutType: .block, containerSize: containerSize, containerPadding: .zero)
//    }
//}

//func absolute(layout: LayoutProperties, in parentSize: Size<Double>) -> (size: Size<Double>, padding: Edges<Double>) {
//
//    // make absolute versions of the layout properties based on the parentSize
//    let absoluteLayout = AbsoluteLayoutProperties(layout, in: parentSize)
//
//    let width: Double = {
//        guard let w = absoluteLayout.width else {
//            return parentSize.width - absoluteLayout.margins.left - absoluteLayout.margins.right
//        }
//        return w
//    }()
//    let height: Double = {
//        return absoluteLayout.height ?? (0 + absoluteLayout.padding.top + absoluteLayout.padding.bottom)
//    }()
//
//    let size = Size(
//        width: width.clamped(min: absoluteLayout.minWidth, max: absoluteLayout.maxWidth),
//        height: height.clamped(min: absoluteLayout.minHeight, max: absoluteLayout.maxHeight)
//    )
//
//    return (size, absoluteLayout.padding)
//}
//
//func positionHorizontally(flex: FlexLayoutProperties, children: [LayoutNode]) -> [LayoutNode] {
//
//
//    let positionedChildren: [LayoutNode] = children.map {
//        var childNode = $0
//        childNode.rect.size = Size(width: 10, height: 10)
//        return childNode
//    }
////    for child in children {
////
////    }
//
//    return positionedChildren
//}
//
//func positionVertically(flex: FlexLayoutProperties, children: inout [LayoutNode]) {
//
//}


struct AbsoluteViewDimensions {
    var size: Size<Double>
    var intrinsicSize: Size<Double?> /// the intrinsic size of the view itself, ignoring subviews
    var contentsSize: Size<Double?> /// the size of all the subviews
    var layout: AbsoluteLayoutProperties
    
    // size minus padding
    var innerSize: Size<Double> {
        return Size(
            width: size.width - layout.padding.left - layout.padding.right,
            height: size.height - layout.padding.top - layout.padding.bottom
        )
    }
    
    // size plus margins
    var outerSize: Size<Double> {
        return Size(
            width: size.width + layout.margins.left + layout.margins.right,
            height: size.height + layout.margins.top + layout.margins.bottom
        )
    }
}

// a container for the sizing functions of all the views
//struct ViewSizing {
//    // a function that, given a container's dimensions, returns the view's dimensions
//    let viewSizer: (_ container: AbsoluteViewDimensions) -> AbsoluteViewDimensions
//
//    //    let viewPositioner
//}

typealias ViewSizer = (_ container: AbsoluteViewDimensions) -> AbsoluteViewDimensions
typealias ViewContentsSizer = (_ view: AbsoluteViewDimensions) -> (contents: Size<Double?>, intrinsic: Size<Double?>)
typealias ViewPositioner = (_ view: AbsoluteViewDimensions, _ container: AbsoluteViewDimensions, _ prevSibling: [(Point<Double>, AbsoluteViewDimensions)]) -> Point<Double>

struct ViewLayouter {
    let sizer: ViewSizer
    let positioner: ViewPositioner
}

typealias ViewLayoutCalculator = (_ container: AbsoluteViewDimensions, _ prevSibling: [AbsoluteViewDimensions]) -> AbsoluteViewDimensions

typealias IntrinsicSizer = (_ sizeConstraint: Size<Double?>) -> Size<Double?>

/**
 Returns a function that, when given a container's dimensions, will return the view's dimensions.
 
 - parameter view: the view to size
 - parameter intrinsicSizer: A function that takes a view and a constraint, and returns an optional size (nil if the view has no intrinsic size)
 - parameter layoutType: how the view is being positioned (absolutely or block-based)... this defines how it falls back if no intrinsic size.
 */
//func viewSizer(
//    viewProperties: ViewProperties,
//    intrinsicSizer: @escaping IntrinsicSizer,
//    layoutType: LayoutType,
//    childSizers: [ViewSizer]
//    ) -> (_ containerDimensions: AbsoluteViewDimensions) -> AbsoluteViewDimensions {
//
//    return { containerDimensions in
//
//        // make absolute versions of the layout properties based on the parentSize
//        let absoluteLayout = AbsoluteLayoutProperties(viewProperties.layout, in: containerDimensions.innerSize)
//
//        let possibleWidth: Double? = {
//            // there is a specific width in the layout properties, so use it
//            if let w = absoluteLayout.width {
//                return w
//            }
//
//            // the layout is absolute, and it has a left && right position, use them to calculate width
//            if layoutType == .absolute, let left = absoluteLayout.position.left, let right = absoluteLayout.position.right {
//                return containerDimensions.size.width - left - right - absoluteLayout.margins.left - absoluteLayout.margins.right
//            }
//
//            // there is a specified width sizeConstraint
//            // this would have been provided by the parent if the parent is static or flex
//            //        if let wConstraint = sizeConstraints.width {
//            //            return wConstraint - absoluteLayout.margins.left - absoluteLayout.margins.right
//            //        }
//
//            // if no specific width, so just the padding size
//            return nil
//        }()
//
//        // use the possible width as a constraint on the intrinsic size
//        let intrinsicSize = intrinsicSizer(
//            Size(width: (possibleWidth ?? containerDimensions.innerSize.width) - absoluteLayout.padding.left - absoluteLayout.padding.right,
//                 height: nil)
//        )
//
//        let isIntrinsicWidth = (possibleWidth != nil || intrinsicSize != nil)
//
//        // get the actual width, using the possibleWidth, intrinsic size, and the layout type.
//        let width: Double = {
//            switch (possibleWidth, layoutType) {
//            case (nil, .absolute):
//                // if we didnt have a specific width, and the layout is absolute, then calculate the width using the intrinsicSizer
//                return (intrinsicSize?.width ?? 0) + absoluteLayout.padding.left + absoluteLayout.padding.right
//            case (nil, .block):
//                // if we didnt have a specific width, and the layout is block, then just fit the width to the container
//                return containerDimensions.innerSize.width - absoluteLayout.margins.left - absoluteLayout.margins.right
//            case (let w?, _):
//                return w
//            }
//        }()
//
//        let height: Double = {
//            // there is a specific height in the layout constraints, so use it
//            if let h = absoluteLayout.height {
//                return h
//            }
//
//            // the layout is absolute, and it has a top && bottom position, use them to calculate width
//            if layoutType == .absolute, let top = absoluteLayout.position.top, let bottom = absoluteLayout.position.bottom {
//                return containerDimensions.size.height - top - bottom - absoluteLayout.margins.top - absoluteLayout.margins.bottom
//            }
//
//            // there is a specified height sizeConstraint
//            // this would have been provided by the parent if the parent is static or flex
//            //        if let hConstraint = sizeConstraints.height {
//            //            return hConstraint - absoluteLayout.margins.top - absoluteLayout.margins.bottom
//            //        }
//
//            // If we are size a block-view-owning view, get the total height of all the child views.
//            // otherwise childHeight is empty.
//            let totalChildrenHeight: Double = {
//
//                // TODO: also flexLayout inherits height of children...
//                // TODO: maybe move this to part of the intrinsicSizer?
//                guard viewProperties.type.childLayoutType == .block else {
//                    return 0
//                }
//
//                let fittingDimensions = AbsoluteViewDimensions(
//                    size: Size(
//                        width: width,
//                        height: containerDimensions.innerSize.height
//                    ),
//                    intrinsicSize: nil,
//                    isIntrinsicWidth: false,
//                    padding: absoluteLayout.padding,
//                    margins: absoluteLayout.margins
//                )
//
//                return childSizers
//                    .reduce((Double(0), Double(0))) {
//
//                        let childDims = $1(fittingDimensions)
//
//                        // store the prev child's bottomMargin
//                        return (
//                            height: $0.0 + childDims.outerSize.height - min($0.1, childDims.margins.top),
//                            prevMargin: childDims.margins.bottom
//                        )
//                    }.0
//            }()
//            // if no specific height, so just the padding size
//            return (intrinsicSize?.height ?? 0) + totalChildrenHeight + absoluteLayout.padding.top + absoluteLayout.padding.bottom
//        }()
//
//        // clamp the generated sizes using the min/max width & height
//        let size = Size(
//            width: width.clamped(min: absoluteLayout.minWidth, max: absoluteLayout.maxWidth),
//            height: height.clamped(min: absoluteLayout.minHeight, max: absoluteLayout.maxHeight)
//        )
//
//        return AbsoluteViewDimensions(
//            size: size,
//            intrinsicSize: intrinsicSize,
//            isIntrinsicWidth: isIntrinsicWidth,
//            padding: absoluteLayout.padding,
//            margins: absoluteLayout.margins
//        )
//    }
//}

// MARK: - Flex Layout
//func flexLayout(
//    view: View,
//    flex: FlexLayoutProperties,
//    leafSizer: ViewSizer,
//    parentLayout: LayoutType,
//    in containerInnerSize: Size<Double>,
//    sizeConstraints: Size<Double?>
//    ) -> LayoutNode {
//    
//    // get the size of the view
////    let (size, padding) = absolute(layout: view.layout, in: containerInnerSize)
//    
//    
//    // make absolute versions of the layout properties based on the parentSize
//    let absoluteLayout = AbsoluteLayoutProperties(view.layout, in: containerInnerSize)
//    
//    let padding = absoluteLayout.padding
//    
//    // Get the size of the view, based on layout properties
//    let size: Size<Double> = {
//        let width: Double = {
//            if let w = absoluteLayout.width {
//                return w
//            }
//            
//            // there is a specified width sizeConstraint
//            // this would have been provided by the parent if the parent is static or flex
//            if let wConstraint = sizeConstraints.width {
//                return wConstraint - absoluteLayout.margins.left - absoluteLayout.margins.right
//            }
//            
//            // if no specific width, so just the padding size
//            return absoluteLayout.padding.left + absoluteLayout.padding.right
//        }()
//        let height: Double = {
//            if let h = absoluteLayout.height {
//                return h
//            }
//            
//            // there is a specified height sizeConstraint
//            // this would have been provided by the parent if the parent is static or flex
//            if let hConstraint = sizeConstraints.height {
//                return hConstraint - absoluteLayout.margins.top - absoluteLayout.margins.bottom
//            }
//            
//            // if no specific height, so just the padding size
//            return absoluteLayout.padding.top + absoluteLayout.padding.bottom
//        }()
//        
//        let size = Size(
//            width: width.clamped(min: absoluteLayout.minWidth, max: absoluteLayout.maxWidth),
//            height: height.clamped(min: absoluteLayout.minHeight, max: absoluteLayout.maxHeight)
//        )
//        
//        return size
//    }()
//    
//    
//    // build all the child nodes, and let them size themselves
//    
//    // do a different layout depending on the direction
//    
//    // the inner size of this view
//    let containerInnerSize = Size(
//        width: size.width - padding.left - padding.right,
//        height: size.height - padding.top - padding.bottom
//    )
//    
//    let childNodes: [LayoutNode]
//    
//    switch flex.direction {
//    case .row:
//        
//        // if stretch then match children to parent's height
//        let childConstraintSize = Size(
//            width: nil,
//            height: flex.itemAlignment == .stretch ? containerInnerSize.height : nil
//        )
//        
//        childNodes = view.children.map {
//            return LayoutNode.build(
//                for: $0,
//                leafSizer: leafSizer,
//                parentLayout: .absolute,
//                in: containerInnerSize,
//                sizeConstraints: childConstraintSize
//            )
//        }
//        
//        
//        
////        childNodes = positionHorizontally(flex: flex, children: childNodes)
//    case .column:
//        // if stretch then match children to parent's width
//        let childConstraintSize = Size(
//            width: flex.itemAlignment == .stretch ? containerInnerSize.width : nil,
//            height: nil
//        )
//        
//        fatalError("Col layout needed")
////        positionVertically(flex: flex, children: &childNodes)
//    }
//    
//    let rect = Rect(
//        origin: .zero,
//        size: size
//    )
//    
//    return LayoutNode(
//        view: (view.id, view.type, view.style),
//        rect: rect,
//        children: childNodes
//    )
//}


// MARK: - Absolute Layout

//func absoluteLayout(view: View, intrinsicSize: ViewSizer, parentLayout: LayoutType, in parentSize: Size<Double>) -> LayoutNode {
//
//    let (size, padding) = absolute(layout: view.layout, in: parentSize)
//
//    var childNodes: [LayoutNode] = []
//    for childView in view.children {
//
//        var childNode = LayoutNode.build(
//            for: childView,
//            intrinsicSize: intrinsicSize,
//            parentLayout: .absolute,
//            in: size
//        )
//
//        let childLayout = AbsoluteLayoutProperties(childView.layout, in: size)
//
//        if let left = childLayout.position.left {
//            childNode.rect.origin.x += left
//        } else if let right = childLayout.position.right {
//            childNode.rect.origin.x = size.width - right - childNode.rect.size.width
//        } else {
//            childNode.rect.origin.x = padding.left
//        }
//
//        if let top = childLayout.position.top {
//            childNode.rect.origin.y += top
//        } else if let bottom = childLayout.position.bottom {
//            childNode.rect.origin.y = size.height - bottom - childNode.rect.size.height
//        } else {
//            childNode.rect.origin.y = padding.top
//        }
//
//        // TODO: apply margins & padding
//        childNodes.append(childNode)
//    }
//
//    let rect = Rect(
//        origin: .zero,
//        size: size
//    )
//
//    return LayoutNode(
//        view: (view.id, view.type, view.style),
//        rect: rect,
//        children: childNodes
//    )
//}

// MARK: - Static Layout

/// Get the size of a leaf view. If the parent was positioned Absolutely then the
//func leafViewSize(view: View, sizer: ViewSizer, containerSize: Size<Double>, parentLayoutType: LayoutType) -> Size<Double> {
//
//    // make absolute versions of the layout properties based on the parentSize.
//    let absoluteLayout = AbsoluteLayoutProperties(view.layout, in: containerSize)
//
//    // how much room we have to fit the view into.
//    let constraintSize = Size(
//        width: (absoluteLayout.width ?? containerSize.width) - absoluteLayout.padding.left - absoluteLayout.padding.right,
//        height: (absoluteLayout.height ?? containerSize.height) - absoluteLayout.padding.top - absoluteLayout.padding.bottom
//    )
//
//    // use the sizer to find the preferred contentSize of the View
//    let contentSize = sizer(view, constraintSize)
//
//    switch parentLayoutType {
//    case .absolute:
//        // if the parent is absolute, then dont make 100% wide by default. Instead use the left/right etc properties if available
//
//        // TODO: padding?
//        let width: Double = {
//            if let w = absoluteLayout.width {
//                // if a specific width is provided, just use that.
//                return w
//            } else if let left = absoluteLayout.position.left,
//                let right = absoluteLayout.position.right {
//                // if there are specific left & right then subtract them from parent width
//                return containerSize.width - left - right
//            } else {
//                // otherwise just use the content's size
//                return contentSize?.width ?? 0
//            }
//        }()
//
//        let height: Double = {
//            if let h = absoluteLayout.height {
//                // if a specific height is provided, just use that.
//                return h
//            } else if let top = absoluteLayout.position.top,
//                let bottom = absoluteLayout.position.bottom {
//                // if there are specific top & bottom then subtract them from parent height
//                return containerSize.height - top - bottom
//            } else {
//                // otherwise just use the content's size
//                return contentSize?.height ?? 0
//            }
//        }()
//
//        let size = Size(
//            width: width.clamped(min: absoluteLayout.minWidth, max: absoluteLayout.maxWidth),
//            height: height.clamped(min: absoluteLayout.minHeight, max: absoluteLayout.maxHeight)
//        )
//        return size
//    case .block:
//
//        // parent is static. Try to use the specified width. Otherwise use the containerWidth
//        let size = Size(
//            width: (absoluteLayout.width ?? containerSize.width).clamped(min: absoluteLayout.minWidth, max: absoluteLayout.maxWidth),
//            height: (absoluteLayout.height ?? contentSize?.height ?? 0).clamped(min: absoluteLayout.minHeight, max: absoluteLayout.maxHeight)
//        )
//        return size
//    }
//}

enum LayoutType {
    case absolute
    case block
    case flex(FlexLayoutProperties)
}

extension ViewType {
    // how the children of this view will be laid out
    var layoutType: LayoutType {
        switch self {
        case .absoluteLayout:
            return .absolute
        case .flexLayout(let flexProperties):
            return .flex(flexProperties)
        default:
            return .block
        }
    }
}

// Build a tree of ViewSizers
func generateLayouters(
    rootNode: TreeNode<ViewProperties>,
    layoutType: LayoutType,
    intrinsicViewSizer: @escaping (ViewProperties) -> IntrinsicSizer
    ) -> TreeNode<(ViewProperties, ViewLayouter)> {
    
    let viewProperties = rootNode.value
    
    // how we are going to size the children (block/flex/absolute)
    let childLayoutType = viewProperties.type.layoutType
    
    // build sizers for all the children
    let childLayouterNodes = rootNode.children.map { childNode in
        return generateLayouters(
            rootNode: childNode,
            layoutType: childLayoutType,
            intrinsicViewSizer: intrinsicViewSizer
        )
    }
    
    let id = viewProperties.id ?? "??"
    
    let contentsSizer: ViewContentsSizer = {
        switch viewProperties.type.layoutType {
        case .block:
            return blockContentsSizer(
                id: id,
                intrinsicSizer: intrinsicViewSizer(viewProperties),
                childSizers: childLayouterNodes.map { $0.value.1.sizer }
            )
        case .absolute:
            return absoluteContentsSizer(id: id)
        case .flex:
            return flexContentsSizer(id: id)
        }
    }()
    
    // the current node's sizer. takes into account the children.
    // depending on the parent type, use different sizing functions for the child
    let sizer: ViewSizer = {
        switch layoutType {
        case .absolute:
            return absoluteSizer(
                id: id,
                layoutProperties: viewProperties.layout,
                contentsSizer: contentsSizer
            )
        case .flex(let flexProperties):
            return flexSizer(
                id: id,
                flexProperties: flexProperties,
                layoutProperties: viewProperties.layout,
                intrinsicSizer: intrinsicViewSizer(viewProperties),
                childSizers: childLayouterNodes.map { $0.value.1.sizer }
            )
        case .block:
            return blockSizer(
                id: id,
                layoutProperties: viewProperties.layout,
                contentsSizer: contentsSizer
            )
        }
    }()
    
    // depending on the parent type, use different positioning functions
    let positioner: ViewPositioner = {
        switch layoutType {
        case .absolute:
            return absoluteChildPositioner()
        case .flex(let flexProperties):
            return flexChildPositioner(flexProperties: flexProperties)
        case .block:
            // TODO: different default gravity if system is right-to-left layout
            let gravity = viewProperties.layout.gravity ?? .left
            // block-positioning
            return blockChildPositioner(gravity: gravity)
        }
    }()
    
    let node = TreeNode(value: (viewProperties, ViewLayouter(sizer: sizer, positioner: positioner)))
    
    childLayouterNodes.forEach {
        node.add(child: $0)
    }
    
    return node
}

//func blockLayout(
//    layoutProperties: LayoutProperties,
//    intrinsicSizer: @escaping IntrinsicSizer,
//    childLayouts: [ViewLayoutCalculator]
//    ) -> ViewLayoutCalculator {
//    return { containerDimensions, prevSiblingDimensions in
//
//        // make absolute versions of the layout properties based on the parentSize
//        let absoluteLayout = AbsoluteLayoutProperties(layoutProperties, in: containerDimensions.innerSize)
//
//        var viewDimensions = AbsoluteViewDimensions(
//            position: .zero,
//            size: .zero,
//            intrinsicSize: nil,
//            isIntrinsicWidth: false,
//            padding: absoluteLayout.padding,
//            margins: absoluteLayout.margins
//        )
//
//        // not-nil if there is a specifc width in the layoutProperties
//        let possibleWidth = absoluteLayout.width
//
//        // use the possible width as a constraint on the intrinsic size
//        viewDimensions.intrinsicSize = intrinsicSizer(
//            Size(width: (possibleWidth ?? containerDimensions.innerSize.width) - viewDimensions.padding.left - viewDimensions.padding.right,
//                 height: nil)
//        )
//
////        let isIntrinsicWidth = (possibleWidth != nil || intrinsicSize != nil)
//
//        // if we didnt have a specific width then just fit the width to the container
//        viewDimensions.size.width = possibleWidth ?? (containerDimensions.innerSize.width - viewDimensions.margins.left - viewDimensions.margins.right)
//
//        // this is to be used for fitting children when calculating the real height
//        viewDimensions.size.height = containerDimensions.innerSize.height
//
//        // calculate the real height, based on the children
//        viewDimensions.size.height = {
//            // there is a specific height in the layout constraints, so use it
//            if let h = absoluteLayout.height {
//                return h
//            }
//
//            // If we are size a block-view-owning view, get the total height of all the child views.
//            // otherwise childHeight is empty.
//            let totalChildrenHeight: Double = {
//
//                // NO. Inner size is calculated depending on the type of the current view.
//                // it would be different
//
//                // calculate the dimensions of all the children fitting into the parent's width.
//                var childDimensions: [AbsoluteViewDimensions] = []
//                for childLayouter in childLayouts {
//                    let childDims = childLayouter(viewDimensions, childDimensions)
//                    childDimensions.append(childDims)
//                }
//
//                // use the bottom edge of the last child
//                if let lastChild = childDimensions.last {
//                    return lastChild.position.y + lastChild.size.height + lastChild.margins.bottom
//                } else {
//                    return 0
//                }
//            }()
//
//            // if no specific height, so just the padding size & child heights
//            return (viewDimensions.intrinsicSize?.height ?? 0) + totalChildrenHeight + viewDimensions.padding.top + absoluteLayout.padding.bottom
//        }()
//
//        // clamp the generated sizes using the min/max width & height
//        let size = Size(
//            width: viewDimensions.size.width.clamped(min: absoluteLayout.minWidth, max: absoluteLayout.maxWidth),
//            height: viewDimensions.size.height.clamped(min: absoluteLayout.minHeight, max: absoluteLayout.maxHeight)
//        )
//
//        let originY: Double = {
//            if let lastSibling = prevSiblingDimensions.last {
//                return lastSibling.position.y + lastSibling.size.height + max(absoluteLayout.margins.top, lastSibling.margins.bottom)
//            } else {
//                return containerDimensions.padding.top + absoluteLayout.margins.top + (containerDimensions.intrinsicSize?.height ?? 0)
//            }
//        }()
//
//        let originX: Double = {
//            // TODO: if system is right-to-left then use .right
//            let defaultGravity: HorizontalGravity = .left
//            switch layoutProperties.gravity ?? defaultGravity {
//            case .left:
//                return containerDimensions.padding.left + absoluteLayout.margins.left
//            case .right:
//                return containerDimensions.size.width - containerDimensions.padding.right - absoluteLayout.margins.right - size.width
//            case .center:
//                return containerDimensions.padding.left + (containerDimensions.innerSize.width / 2) - (absoluteLayout.outerSize.width / 2) + absoluteLayout.margins.left
//            }
//        }()
//
//
//        return Point(
//            x: originX,
//            y: originY
//        )
//
//
//        return AbsoluteViewDimensions(
//            position: .zero,
//            size: size,
//            intrinsicSize: intrinsicSize,
//            isIntrinsicWidth: isIntrinsicWidth,
//            padding: absoluteLayout.padding,
//            margins: absoluteLayout.margins
//        )
//
//
//
//
//        return AbsoluteViewDimensions(
//            position: <#T##Point<Double>#>,
//            size: <#T##Size<Double>#>,
//            intrinsicSize: <#T##Size<Double>?#>,
//            isIntrinsicWidth: <#T##Bool#>,
//            padding: <#T##Edges<Double>#>,
//            margins: <#T##Edges<Double>#>
//        )
//    }
//}

// MARK: - Sizers

/**
 Generates a function that will produce the size of the contents of a block view (not including the view's padding).
 The size of this view's children are used to calculate the height if there is no specific height.
 The size that is passed-in is the max-size the view has to fit into (eg. the innerSize of the view)
 */
func blockContentsSizer(
    id: String,
    intrinsicSizer: @escaping IntrinsicSizer,
    childSizers: [ViewSizer]
    ) -> ViewContentsSizer {
    return { viewDimensions in
        
        
        print("[BLK.c] '\(id)' in \(viewDimensions.innerSize) ....")
        
        let innerWidth = viewDimensions.innerSize.width
        
        // use the view's width as a constraint on the intrinsic size
        let intrinsicSize = intrinsicSizer(Size(
            width: innerWidth,
            height: nil)
        )
        
//        var childDimensions: [AbsoluteViewDimensions] = []
//        var totalChildrenHeight: Double = 0
//        for childSizer in childSizers {
//
//        }
//
        // make the height equal to the sum of the height of all the children
        // Block-based views do a weird dance with their inter-element margins,
        // where the `max` of the (n-1) view's marginBottom & current view's marginTop
        // is used as the space between
        let (totalChildrenHeight, _, maxChildWidth) = childSizers
            .reduce((Double(0), Double(0), Optional<Double>.none)) {
                
                let childDims = $1(viewDimensions)
                
                var maxWidth = $0.2
                if childDims.contentsSize.width != nil {
                    maxWidth = max(maxWidth ?? 0, childDims.outerSize.width)
                }
                
                // store the prev child's bottomMargin
                return (
                    height: $0.0 + childDims.outerSize.height - min($0.1, childDims.layout.margins.top),
                    prevMargin: childDims.layout.margins.bottom,
                    maxWidth: maxWidth
                )
        }
        
//        // get the total height of all the child views.
//        let totalChildrenHeight: Double = {
//
//        }()
        
        var possibleHeight = intrinsicSize.height
        if !childSizers.isEmpty {
            possibleHeight = (possibleHeight ?? 0) + totalChildrenHeight
        }
        
        let size = Size(width: intrinsicSize.width ?? maxChildWidth,
                        height: possibleHeight)
        
        
        print("[BLK.c] '\(id)' size: \(size) intrinsic: \(intrinsicSize)")
        
        // if no specific height, so just the padding size & child heights
        return (size, intrinsicSize)
    }
}

/**
 Generates a function that will produce the size of the contents of an absolute view (not including the view's padding).
 Absolute views do not use their child-views, and are just 0 sized, unless they have
 */
func absoluteContentsSizer(
    id: String
    ) -> ViewContentsSizer {
    return { viewDimensions in
        
        print("abs-ContentsSizer '\(id)'")
        
        return (Size(width: nil, height: nil), Size(width: nil, height: nil))
    }
}

func flexContentsSizer(
    id: String
    ) -> ViewContentsSizer {
    return { viewDimensions in
        
        print("flex-ContentsSizer '\(id)'")
        
        return (Size(width: nil, height: nil), Size(width: nil, height: nil))
    }
}

/**
 Generates a function that will produce the size of a view that is within a block view.
 The size of this view's children are used to calculate the height if there is no specific height.
 */
func blockSizer(
    id: String,
    layoutProperties: LayoutProperties,
    contentsSizer: @escaping ViewContentsSizer
    ) -> ViewSizer {
    return { containerDimensions in
        
        print("[BLK] '\(id)' in \(containerDimensions.innerSize) ....")
        
        // make absolute versions of the layout properties based on the parentSize
        var viewDimensions = AbsoluteViewDimensions(
            size: .zero,
            intrinsicSize: Size(width: nil, height: nil),
            contentsSize: Size(width: nil, height: nil),
            layout: AbsoluteLayoutProperties(layoutProperties, in: containerDimensions.innerSize)
        )
        
        // if we didnt have a specific width then just fit the width to the container, ignoring the intrinsic size.
        if let concreteWidth = viewDimensions.layout.width {
            // there is a specific width in the layout constraints, so use it
            viewDimensions.size.width = concreteWidth
            viewDimensions.contentsSize.width = concreteWidth - viewDimensions.layout.padding.left - viewDimensions.layout.padding.right
        } else {
            viewDimensions.size.width = containerDimensions.innerSize.width - viewDimensions.layout.margins.left - viewDimensions.layout.margins.right
        }
    
        if let concreteHeight = viewDimensions.layout.height {
            // there is a specific height in the layout constraints, so use it
            viewDimensions.size.height = concreteHeight
            viewDimensions.contentsSize.height = concreteHeight - viewDimensions.layout.padding.top - viewDimensions.layout.padding.bottom
        } else {
            
            // calculate the contents size of the view fitting within the view's width
            var fittingDimensions = viewDimensions
            fittingDimensions.size.height = .greatestFiniteMagnitude

            // calculate & save the size of the contents
            let (contentsSize, intrinsicSize) = contentsSizer(fittingDimensions)
            
            viewDimensions.contentsSize = Size(width: viewDimensions.contentsSize.width ?? contentsSize.width,
                                               height: viewDimensions.contentsSize.height ?? contentsSize.height)
            viewDimensions.intrinsicSize = intrinsicSize
            
            // use the contents height (or zero) to be the actual height
            viewDimensions.size.height = (viewDimensions.contentsSize.height ?? 0) + viewDimensions.layout.padding.top + viewDimensions.layout.padding.bottom
        }
        
        // clamp the generated sizes using the min/max width & height
        viewDimensions.size = Size(
            width: viewDimensions.size.width.clamped(
                min: viewDimensions.layout.minWidth,
                max: viewDimensions.layout.maxWidth
            ),
            height: viewDimensions.size.height.clamped(
                min: viewDimensions.layout.minHeight,
                max: viewDimensions.layout.maxHeight
            )
        )
        
        print("[BLK] '\(id)' size: \(viewDimensions.size) contents: \(viewDimensions.contentsSize) intrinsic: \(viewDimensions.contentsSize) ")
        
        return viewDimensions
    }
}

/**
 Generates a function that will produce the size of a view that is within an AbsoluteLayout view.
 The size of the view's children will be ignored.
 */
func absoluteSizer(
    id: String,
    layoutProperties: LayoutProperties,
    contentsSizer: @escaping ViewContentsSizer
    ) -> ViewSizer {
    return { containerDimensions in
        
        print("absolute-Sizer '\(id)'")
        
        // make absolute versions of the layout properties based on the parentSize
        var viewDimensions = AbsoluteViewDimensions(
            size: .zero,
            intrinsicSize: Size(width: nil, height: nil),
            contentsSize: Size(width: nil, height: nil),
            layout: AbsoluteLayoutProperties(layoutProperties, in: containerDimensions.innerSize)
        )
        
        // find the width specified in the layout properties, or nil if no width specified
        let concreteWidth: Double? = {
            // there is a specific width in the layout properties, so use it
            if let w = viewDimensions.layout.width {
                return w
            }
        
            // the layout is absolute, and it has a left && right position, use them to calculate width
            if let left = viewDimensions.layout.position.left, let right = viewDimensions.layout.position.right {
                return containerDimensions.size.width - left - right - viewDimensions.layout.margins.left - viewDimensions.layout.margins.right
            }
            
            return nil
        }()
        
        // find the height specified in the layout properties, or nil if no width specified
        let concreteHeight: Double? = {
            // there is a specific height in the layout constraints, so use it
            if let h = viewDimensions.layout.height {
                return h
            }
            
            // the layout is absolute, and it has a top && bottom position, use them to calculate width
            if let top = viewDimensions.layout.position.top, let bottom = viewDimensions.layout.position.bottom {
                return containerDimensions.size.height - top - bottom - viewDimensions.layout.margins.top - viewDimensions.layout.margins.bottom
            }
            
            return nil
        }()
        
        // if we didnt have a specific width then just fit the width to the container, ignoring the intrinsic size.
//        viewDimensions.size.width = possibleWidth ?? (containerDimensions.innerSize.width - viewDimensions.layout.margins.left - viewDimensions.layout.margins.right)
//        viewDimensions.size.height = possibleHeight ?? (containerDimensions.innerSize.height - viewDimensions.layout.margins.left - viewDimensions.layout.margins.right)
        
        viewDimensions.size = Size(width: concreteWidth ?? containerDimensions.innerSize.width,
                                   height: concreteHeight ?? containerDimensions.innerSize.height)
        
//        if let w = possibleWidth, let h = possibleHeight {
//            // we have specific width & height dimensions, so use them
//            viewDimensions.size = Size(width: w, height: h)
//        } else {
//
//        }
//
        
        if concreteWidth == nil || concreteHeight == nil {
            // we dont have absolute dimensions for both height & width - we will need to calculate the contents size
//            let fittingDimensions = viewDimensions

            let (possibleContentsSize, intrinsicSize) = contentsSizer(viewDimensions)
            
            let contentsSize = Size(
                width: (possibleContentsSize.width ?? 0) + viewDimensions.layout.padding.left + viewDimensions.layout.padding.right,
                height: (possibleContentsSize.height ?? 0) + viewDimensions.layout.padding.top + viewDimensions.layout.padding.bottom
            )
            
            viewDimensions.size = Size(width: concreteWidth ?? contentsSize.width,
                                       height: concreteHeight ?? contentsSize.height)
        }
        
        
        
//            viewDimensions.size.height = {
//                // there is a specific height in the layout constraints, so use it
//                if let h = viewDimensions.layout.height {
//                    return h
//                }
//
//                var fittingDimensions = viewDimensions
//                fittingDimensions.size.height = .greatestFiniteMagnitude
//
//                // calculate the size of the contents
//                let contentSize = contentsSizer(fittingDimensions)
//
//                return contentSize.height + viewDimensions.layout.padding.top + viewDimensions.layout.padding.bottom
//            }()
//
//
//        // use the possible width as a constraint on the intrinsic size
//        let intrinsicSize = intrinsicSizer(
//            Size(width: (possibleWidth ?? containerDimensions.innerSize.width) - absoluteLayout.padding.left - absoluteLayout.padding.right,
//                 height: nil)
//        )
//
////        let isIntrinsicWidth = (possibleWidth != nil || intrinsicSize != nil)
//
//        // get the actual width, using the possibleWidth & intrinsic size
//        // if we didnt have a specific width, then calculate the width using the intrinsicSizer
//        let width: Double = possibleWidth ?? (intrinsicSize?.width ?? 0) + absoluteLayout.padding.left + absoluteLayout.padding.right
//
//        let height: Double = {
//            // there is a specific height in the layout constraints, so use it
//            if let h = absoluteLayout.height {
//                return h
//            }
//
//            // the layout is absolute, and it has a top && bottom position, use them to calculate width
//            if let top = absoluteLayout.position.top, let bottom = absoluteLayout.position.bottom {
//                return containerDimensions.size.height - top - bottom - absoluteLayout.margins.top - absoluteLayout.margins.bottom
//            }
//
//            return (intrinsicSize?.height ?? 0) + absoluteLayout.padding.top + absoluteLayout.padding.bottom
//        }()
        
        // clamp the generated sizes using the min/max width & height
        viewDimensions.size = Size(
            width: viewDimensions.size.width.clamped(
                min: viewDimensions.layout.minWidth,
                max: viewDimensions.layout.maxWidth
            ),
            height: viewDimensions.size.height.clamped(
                min: viewDimensions.layout.minHeight,
                max: viewDimensions.layout.maxHeight
            )
        )
        
        return viewDimensions
    }
}

/**
 Generates a function that will produce the size of a view that is within an FlexLayout view.
 */
func flexSizer(
    id: String,
    flexProperties: FlexLayoutProperties,
    layoutProperties: LayoutProperties,
    intrinsicSizer: @escaping IntrinsicSizer,
    childSizers: [ViewSizer]
    ) -> ViewSizer {
    return { containerDimensions in
        
        print("flex-Sizer '\(id)'")
        
        // make absolute versions of the layout properties based on the parentSize
        let absoluteLayout = AbsoluteLayoutProperties(layoutProperties, in: containerDimensions.innerSize)
        
        // not-nil if there is a specifc width in the layoutProperties
        let possibleWidth = absoluteLayout.width
        
        // use the possible width as a constraint on the intrinsic size
        let intrinsicSize = intrinsicSizer(
            Size(width: (possibleWidth ?? containerDimensions.innerSize.width) - absoluteLayout.padding.left - absoluteLayout.padding.right,
                 height: nil)
        )
        
        let width: Double = {
            
            // if column direction:
            
            // if we didnt have a specific width then just fit the width to the container
            switch flexProperties.itemAlignment {
            case .stretch:
                // use container size
                return possibleWidth ?? (containerDimensions.innerSize.width - absoluteLayout.margins.left - absoluteLayout.margins.right)
            default:
                // just use the intrinsic size
                return possibleWidth ?? (intrinsicSize.width ?? 0) + absoluteLayout.padding.left + absoluteLayout.padding.right
            }
        }()
            
        let height: Double = {
            // there is a specific height in the layout constraints, so use it
            if let h = absoluteLayout.height {
                return h
            }
            
            // If we are size a block-view-owning view, get the total height of all the child views.
            // otherwise childHeight is empty.
            let totalChildrenHeight: Double = {
                
                let fittingDimensions = AbsoluteViewDimensions(
                    size: Size(
                        width: width,
                        height: containerDimensions.innerSize.height
                    ),
                    intrinsicSize: Size(width: nil, height: nil),
                    contentsSize: Size(width: nil, height: nil),
                    layout: absoluteLayout
                )
                
                // make the height equal to the sum of the height of all the children
                // Block-based views do a weird dance with their inter-element margins,
                // where the `max` of the (n-1) view's marginBottom & current view's marginTop
                // is used as the space between
                return childSizers
                    .reduce((Double(0), Double(0))) {
                        
                        let childDims = $1(fittingDimensions)
                        
                        // store the prev child's bottomMargin
                        return (
                            height: $0.0 + childDims.outerSize.height - min($0.1, childDims.layout.margins.top),
                            prevMargin: childDims.layout.margins.bottom
                        )
                    }.0
            }()
            
            // if no specific height, so just the padding size & child heights
            return (intrinsicSize.height ?? 0) + totalChildrenHeight + absoluteLayout.padding.top + absoluteLayout.padding.bottom
        }()
        
        // clamp the generated sizes using the min/max width & height
        let size = Size(
            width: width.clamped(min: absoluteLayout.minWidth, max: absoluteLayout.maxWidth),
            height: height.clamped(min: absoluteLayout.minHeight, max: absoluteLayout.maxHeight)
        )
        
        return AbsoluteViewDimensions(
            size: size,
            intrinsicSize: Size(width: nil, height: nil),
            contentsSize: Size(width: nil, height: nil),
            layout: absoluteLayout
        )
    }
}

// MARK: - Positioners

/**
 Generates a function that will produce the position of a view that is the child of a Block view.
 */
func blockChildPositioner(gravity: HorizontalGravity) -> ViewPositioner {
    return { viewDims, containerDims, prevSiblings in
        
        let originY: Double = {
            if let lastSibling = prevSiblings.last {
                return lastSibling.0.y + lastSibling.1.size.height + max(viewDims.layout.margins.top, lastSibling.1.layout.margins.bottom)
            } else {
                // position the first child below the intrinsic contents (eg. below the text in a label)
                return containerDims.layout.padding.top + viewDims.layout.margins.top + (containerDims.intrinsicSize.height ?? 0)
            }
        }()
        
        let originX: Double = {
            switch gravity {
            case .left:
                return containerDims.layout.padding.left + viewDims.layout.margins.left
            case .right:
                return containerDims.size.width - containerDims.layout.padding.right - viewDims.layout.margins.right - viewDims.size.width
            case .center:
                return containerDims.layout.padding.left + (containerDims.innerSize.width / 2) - (viewDims.outerSize.width / 2) + viewDims.layout.margins.left
            }
        }()
        return Point(
            x: originX,
            y: originY
        )
    }
}

/**
 Generates a function that will produce the position of a view that is the child of an AbsoluteLayout view.
 */
func absoluteChildPositioner() -> ViewPositioner {
    return { viewDims, containerDims, prevSiblings in
        
        let originX: Double = {
            if let left = viewDims.layout.position.left {
                return left + viewDims.layout.margins.left
            } else if let right = viewDims.layout.position.right {
                return containerDims.size.width - right - viewDims.layout.margins.right - viewDims.size.width
            } else {
                return containerDims.layout.padding.left + viewDims.layout.margins.left
            }
        }()
        
        let originY: Double = {
            if let top = viewDims.layout.position.top {
                return top + viewDims.layout.margins.top
            } else if let bottom = viewDims.layout.position.bottom {
                return containerDims.size.height - bottom - viewDims.layout.margins.bottom - viewDims.size.height
            } else {
                return containerDims.layout.padding.top + viewDims.layout.margins.top
            }
        }()
        return Point(
            x: originX,
            y: originY
        )
    }
}

/**
 Generates a function that will produce the position of a view that is the child of an FlexLayout view.
 */
func flexChildPositioner(flexProperties: FlexLayoutProperties) -> ViewPositioner {
    return { viewDims, containerDims, prevSiblings in
        
        switch flexProperties.direction {
        case .row:
            
            fatalError()
            
        case .column:
            
            let originY: Double = {
                
                // TODO: justification
                
                if let lastSibling = prevSiblings.last {
                    return lastSibling.0.y + lastSibling.1.size.height + lastSibling.1.layout.margins.bottom + viewDims.layout.margins.top
                } else {
                    return containerDims.layout.padding.top + viewDims.layout.margins.top + (containerDims.intrinsicSize.height ?? 0)
                }
            }()
            
            let originX: Double = {
                switch flexProperties.itemAlignment {
                case .center:
                    return containerDims.layout.padding.left + (containerDims.innerSize.width / 2) - (viewDims.outerSize.width / 2) + viewDims.layout.margins.left
                case .stretch,
                     .flexStart,
                     .baseline:
                    return containerDims.layout.padding.left + viewDims.layout.margins.left
                case .flexEnd:
                    return containerDims.size.width - containerDims.layout.padding.right - viewDims.layout.margins.right - viewDims.size.width
                }
            }()
            
            return Point(
                x: originX,
                y: originY
            )
        }
    }
}

// MARK: -

//func generateChildPositioners(
//    rootNode: TreeNode<(ViewProperties, ViewSizer)>,
//    rootPositioner: @escaping ViewPositioner
//) -> TreeNode<(ViewProperties, ViewSizer, ViewPositioner)> {
//
//    // A node only positions it's children, not itself
//
//    let node = TreeNode<(ViewProperties, ViewSizer, ViewPositioner)>(value: (rootNode.value.0, rootNode.value.1, rootPositioner))
//
//    for child in rootNode.children {
//
//        // depending on the parent type, use different positioning functions
//        let childPositioner: ViewPositioner
//        switch rootNode.value.0.type {
//        case .absoluteLayout:
//            childPositioner = absolutePositioner()
//        case .flexLayout(let flexProperties):
//            childPositioner = flexPositioner(flexProperties: flexProperties)
//        default:
//            // TODO: different default gravity if system is right-to-left layout
//            let gravity = child.value.0.layout.gravity ?? .left
//            // block-positioning
//            childPositioner = blockPositioner(gravity: gravity)
//        }
//
//        let positionedChildNode = generateChildPositioners(rootNode: child, rootPositioner: childPositioner)
//
//        node.add(child: positionedChildNode)
//    }
//
//    return node
//}

// given a tree of sizers, walk down calculating the actual dimensions
func resolveLayouters(rootNode: TreeNode<(ViewProperties, ViewLayouter)>, rootSize: Size<Double>) -> TreeNode<(view: ViewProperties, dimensions: AbsoluteViewDimensions, position: Point<Double>)> {
    
    return rootNode.mapTree { viewNode, newParent in
        
        let (viewProperties, viewLayouter) = viewNode.value
        
        print("Sizing \(viewProperties.id ?? "??")")
        
        let containerDimensions = newParent?.value.dimensions ?? AbsoluteViewDimensions(
            size: rootSize,
            intrinsicSize: Size(width: nil, height: nil),
            contentsSize: Size(width: nil, height: nil),
            layout: AbsoluteLayoutProperties(.empty, in: rootSize)
        )
        
        // use the container dimensions to calculate the child's dimensions
        let viewDimensions = viewLayouter.sizer(containerDimensions)
        
        let prevSiblings = newParent?.children.map { ($0.value.position, $0.value.dimensions) } ?? []
        let viewPosition = viewLayouter.positioner(viewDimensions, containerDimensions, prevSiblings)
        
        return (viewProperties, viewDimensions, viewPosition)
    }
}



/// Generate a LayoutNode for a View and it's children, fitting inside parentSize.
/// The LayoutNode's rect is sized, and it's children positioned, but it's origin is not modified eg. it's margin is not taken into account (that is the job of the parent node's layout method)
//func staticLayout(
//    view: ViewNode,
//    intrinsicSizer: @escaping ViewSizer,
//    layoutType: LayoutType,
//    containerSize: Size<Double>,
//    containerPadding: Edges<Double>
//    ) -> LayoutNode {
//
//    // make absolute versions of the layout properties based on the parentSize
//    let absoluteLayout = AbsoluteLayoutProperties(view.value.layout, in: containerSize)
//
//    let containerInnerSize = Size(
//        width: containerSize.width - containerPadding.left - containerPadding.right,
//        height: containerSize.height - containerPadding.top - containerPadding.bottom
//    )
//
//    // build the viewSizing properties of the node
//    let viewSizing = ViewSizing(
//        viewSizer: viewSize(
//            view: view,
//            intrinsicSizer: intrinsicSizer,
//            layoutType: layoutType
//        )
//    )
//
////    for childNode in view.children {
////        childNode.value
////    }
//
//    let (preferredSize, isIntrinsicWidth) = viewSize(
//        view: view,
//        intrinsicSizer: intrinsicSizer,
//        layoutType: layoutType
//    )(containerSize, containerPadding)
//
//    var childNodes: [LayoutNode] = []
//    let size: Size<Double>
//
//    if view.children.isEmpty {
//
//        size = preferredSize
//
//    } else {
//        // the size into which the children will try to fit.
//        let fittingSize = Size(
//            width: isIntrinsicWidth ? preferredSize.width : containerInnerSize.width,
//            height: containerInnerSize.height
//        )
//
//        // convert children to layoutNodes, positioning them vertically
//        var originY = absoluteLayout.padding.top
//        var maxChildWidth: Double = 0
//
//        var childNodesAndMargins: [(LayoutNode, margin: Edges<Double>)] = view.children.map { childView in
//
//            var childNode = LayoutNode.build(
//                view: childView,
//                intrinsicSizer: intrinsicSizer,
//                layoutType: .block,
//                containerSize: fittingSize,
//                containerPadding: absoluteLayout.padding
//            )
//
//            let childMargins = childView.layout.margins.absolute(in: preferredSize)
//
//            // position vertically
//            childNode.rect.origin.y = originY + childMargins.top
//
//            // move the next child's originY down
//            originY = childNode.rect.origin.y + childNode.rect.size.height + childMargins.bottom
//
//            maxChildWidth = max(maxChildWidth, childNode.rect.size.width + childMargins.left + childMargins.right + absoluteLayout.padding.left + absoluteLayout.padding.right)
//
//            return (childNode, childMargins)
//        }
//
//        let totalChildHeight = originY + absoluteLayout.padding.bottom
//
//        if isIntrinsicWidth {
//            // preferred width was intrinsic, so just use it, and set the height to be that of all the children
//            size = Size(
//                width: preferredSize.width,
//                height: totalChildHeight.clamped(min: absoluteLayout.minHeight, max: absoluteLayout.maxHeight)
//            )
//        } else {
//            // if the width was not intrinsic, then re-size the children based on the maxChildWidth as the fitting size
//            // TODO: re-calc and map sizes
//            let newFittingSize = Size(
//                width: maxChildWidth,
//                height: containerInnerSize.height
//            )
//
////            childNodesAndMargins = childNodesAndMargins.map {
////                var (childNode, margin) = $0
////
//////                let preferredChildSize = viewSize(
//////                    view: childNode.view, containerSize: <#T##Size<Double>#>, containerPadding: <#T##Edges<Double>#>, intrinsicSizer: <#T##(View, Size<Double?>) -> Size<Double>?#>, layoutType: <#T##LayoutType#>)
////
//////                childNode.rect.size
////
////                return (childNode, margin)
////            }
//
//            size = Size(
//                width: preferredSize.width,
//                height: totalChildHeight.clamped(min: absoluteLayout.minHeight, max: absoluteLayout.maxHeight)
//            )
//        }
//
//        // position the children horizontally now we know the size of the parent
//        childNodes = childNodesAndMargins.map {
//            var childNode = $0.0
//            let childMargin = $0.margin
//
//            // TODO: use the child's gravity
//            switch view.layout.gravity {
//            case .right?:
//                childNode.rect.origin.x = size.width - absoluteLayout.padding.right - childNode.rect.size.width - childMargin.right
//
//            case .left?:
//                // TODO: different depending on gravity. Defaults to no gravity (system LtR or RtL)
//                childNode.rect.origin.x = absoluteLayout.padding.left + childMargin.left
//
//            case .center?,
//                 nil:
//                childNode.rect.origin.x = (size.width / 2) - (childNode.rect.size.width / 2)
//            }
//
//            return childNode
//        }
//    }
//
//    let rect = Rect(
//        origin: .zero,
//        size: Size(
//            width: size.width,
//            height: size.height
//        )
//    )
//
//    return LayoutNode(
//        view: (view.id, view.type, view.style),
//        rect: rect,
//        children: childNodes
//    )
//}
