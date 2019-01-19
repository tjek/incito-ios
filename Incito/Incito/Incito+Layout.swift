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

    var size: Size<Double?> // nil if fitting to child
    
    var transform: Transform<Double>
}

extension AbsoluteLayoutProperties {
    /// parentSize is the container's inner size (size - padding)
    init(_ properties: LayoutProperties, in parentSize: Size<Double>) {
        self.maxWidth = properties.maxWidth?.absolute(in: parentSize.width) ?? .infinity
        self.minWidth = properties.minWidth?.absolute(in: parentSize.width) ?? 0
        self.maxHeight = properties.maxHeight?.absolute(in: parentSize.height) ?? .infinity
        self.minHeight = properties.minHeight?.absolute(in: parentSize.height) ?? 0
        
        self.size = Size(width: properties.width?.absolute(in: parentSize.width),
                         height: properties.height?.absolute(in: parentSize.height))
        
        self.position = properties.position.absolute(in: parentSize)
        
        // margins & padding are actually only relative to the width of the parent, not the height
        let squareParentSize = Size(width: parentSize.width, height: parentSize.width)
        self.margins = properties.margins.absolute(in: squareParentSize)
        self.padding = properties.padding.absolute(in: squareParentSize)
        
        self.transform = Transform(
            scale: properties.transform.scale,
            translate: Point(
                x: properties.transform.translate.x.absolute(in: parentSize.width),
                y: properties.transform.translate.y.absolute(in: parentSize.height)
            ),
            rotate: properties.transform.rotate
        )
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

typealias ViewSizer = (_ container: AbsoluteViewDimensions) -> AbsoluteViewDimensions
typealias ViewContentsSizer = (_ view: AbsoluteViewDimensions) -> (contents: Size<Double?>, intrinsic: Size<Double?>)
typealias ViewPositioner = (_ view: AbsoluteViewDimensions, _ container: AbsoluteViewDimensions, _ prevSiblings: [AbsoluteViewDimensions], _ nextSiblings: [AbsoluteViewDimensions]) -> Point<Double>
typealias ViewSizeTweaker = (_ view: AbsoluteViewDimensions, _ container: AbsoluteViewDimensions, _ prevSiblings: [AbsoluteViewDimensions], _ nextSiblings: [AbsoluteViewDimensions]) -> AbsoluteViewDimensions

struct ViewLayouter {
    let sizer: ViewSizer
    let sizeTweaker: ViewSizeTweaker?
    let positioner: ViewPositioner
}

typealias ViewLayoutCalculator = (_ container: AbsoluteViewDimensions, _ prevSibling: [AbsoluteViewDimensions]) -> AbsoluteViewDimensions

typealias IntrinsicSizer = (_ sizeConstraint: Size<Double?>) -> Size<Double?>

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

extension TreeNode where T == ViewProperties {
    
    /// Builds a tree of functions that, when given a root size, will calculate sizes & positions for all the nodes in the tree.
    func generateLayouterTree(
        layoutType: LayoutType,
        intrinsicViewSizer: @escaping (ViewProperties) -> IntrinsicSizer
        ) -> TreeNode<(ViewProperties, ViewLayouter)> {
        
        let viewProperties = self.value
        
        // how we are going to size the children (block/flex/absolute)
        let childLayoutType = viewProperties.type.layoutType
        
        // build sizers for all the children
        let childLayouterNodes = self.children.map { childNode in
            return childNode.generateLayouterTree(
                layoutType: childLayoutType,
                intrinsicViewSizer: intrinsicViewSizer
            )
        }
        
        // make the function that will calculate the inner-size of the view, based on the sizer-functions of all its children.
        let contentsSizer: ViewContentsSizer = {
            switch viewProperties.type.layoutType {
            case .block:
                return blockContentsSizer(
                    intrinsicSizer: intrinsicViewSizer(viewProperties),
                    childSizers: childLayouterNodes.map { $0.value.1.sizer }
                )
            case .absolute:
                return absoluteContentsSizer()
            case .flex(let flex):
                return flexContentsSizer(
                    flexProperties: flex,
                    intrinsicSizer: intrinsicViewSizer(viewProperties),
                    childSizers: childLayouterNodes.map { $0.value.1.sizer }
                )
            }
        }()
        
        // make a function that will calculate the size of this node given the type of the parent (eg. flex/abs/block) and the inner-size calculating function.
        let sizer: ViewSizer = {
            switch layoutType {
            case .absolute:
                return absoluteChildSizer(
                    layoutProperties: viewProperties.layout,
                    contentsSizer: contentsSizer
                )
            case .flex(let flexProperties):
                
                let normalizedGrow: Double? = {
                    guard let flexGrow = viewProperties.layout.flexGrow, flexGrow > 0 else {
                        return nil
                    }
                    let totalGrow: Double = self.siblings(excludeSelf: false).reduce(0) {
                        $0 + ($1.value.layout.flexGrow ?? 0)
                    }
                    return totalGrow == 0 ? nil : flexGrow / totalGrow
                }()
                
                return flexChildSizer(
                    flexProperties: flexProperties,
                    layoutProperties: viewProperties.layout,
                    normalizedGrow: normalizedGrow,
                    contentsSizer: contentsSizer
                )
            case .block:
                return blockChildSizer(
                    layoutProperties: viewProperties.layout,
                    contentsSizer: contentsSizer
                )
            }
        }()
        
        let sizeTweaker: ViewSizeTweaker? = {
            switch layoutType {
            case .flex(let flexProperties):
                return nil
                
//                guard let normGrow = normalizedGrow else {
//                    return nil
//                }
//
//                return flexChildSizeTweaker(
//                    flexProperties: flexProperties,
//                    normalizedFlexGrow: normGrow
//                )
                
            case .absolute,
                 .block:
                return nil
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
        
        let node = TreeNode<(ViewProperties, ViewLayouter)>(value: (viewProperties, ViewLayouter(sizer: sizer, sizeTweaker: sizeTweaker, positioner: positioner)))
        
        childLayouterNodes.forEach {
            node.add(child: $0)
        }
        
        return node
    }
}

// MARK: - Contents Sizers

/**
 Generates a function that will produce the size of the contents of a block view (not including the view's padding).
 The size of this view's children are used to calculate the height if there is no specific height.
 The size that is passed-in is the max-size the view has to fit into (eg. the innerSize of the view)
 */
func blockContentsSizer(
    intrinsicSizer: @escaping IntrinsicSizer,
    childSizers: [ViewSizer]
    ) -> ViewContentsSizer {
    return { viewDimensions in
        
        let innerWidth = viewDimensions.innerSize.width
        
        // use the view's width as a constraint on the intrinsic size
        let intrinsicSize = intrinsicSizer(Size(
            width: innerWidth,
            height: nil)
        )
        
        // make the height equal to the sum of the height of all the children
        // Block-based views do a weird dance with their inter-element margins,
        // where the `max` of the (n-1) view's marginBottom & current view's marginTop
        // is used as the space between
        let (totalChildrenHeight, _, maxChildWidth) = childSizers
            .reduce((Double(0), Double(0), Optional<Double>.none)) {
                
                let childDims = $1(viewDimensions)
                
                var maxWidth = $0.2
                if let childContentsWidth = childDims.contentsSize.width {
                    maxWidth = max(maxWidth ?? 0, childContentsWidth + childDims.layout.margins.left + childDims.layout.margins.right + childDims.layout.padding.left + childDims.layout.margins.right)
                }
                
                // store the prev child's bottomMargin
                return (
                    height: $0.0 + childDims.outerSize.height - min($0.1, childDims.layout.margins.top),
                    prevMargin: childDims.layout.margins.bottom,
                    maxWidth: maxWidth
                )
        }
        
        var possibleHeight = intrinsicSize.height
        if !childSizers.isEmpty {
            possibleHeight = (possibleHeight ?? 0) + totalChildrenHeight
        }
        
        let size = Size(width: intrinsicSize.width ?? maxChildWidth,
                        height: possibleHeight)
        
        // if no specific height, so just the padding size & child heights
        return (size, intrinsicSize)
    }
}

/**
 Generates a function that will produce the size of the contents of an AbsoluteLayout view (not including the view's padding).
 Absolute views have no intrinsic or contents size.
 */
func absoluteContentsSizer() -> ViewContentsSizer {
    return { _ in
        return (Size(width: nil, height: nil), Size(width: nil, height: nil))
    }
}

/**
 Generates a function that will produce the size of the contents of a FlexLayout view (not including the view's padding). So basically the `innerSize` of the flexlayout view.
 The size of this view's children are used to calculate the height if there is no specific height.
 */
func flexContentsSizer(
    flexProperties: FlexLayoutProperties,
    intrinsicSizer: @escaping IntrinsicSizer,
    childSizers: [ViewSizer]
    ) -> ViewContentsSizer {
    return { viewDimensions in
        
        // TODO: flex-basis may/will affect this
        
        switch flexProperties.direction {
        case .column:
            // calculate the innersize of the flex view when the subviews are positioned vertically
            
            // get the total height of all the children.
            // also get the maxWidth of all the children (if they are not flexibly sized)
            let (totalChildrenHeight, maxChildWidth) = childSizers
                .reduce((Double(0), Optional<Double>.none)) {
                    
                    let childDims = $1(viewDimensions)
                    
                    var maxWidth = $0.1
                    // only use the child's outersize if it has concrete contents size
                    if childDims.contentsSize.width != nil {
                        maxWidth = max(maxWidth ?? 0, childDims.outerSize.width)
                    }
                    
                    return (
                        height: $0.0 + childDims.outerSize.height,
                        maxWidth: maxWidth
                    )
            }
            
            // if the view has children then use the totalHeight, otherwise not height
            let possibleHeight: Double? = childSizers.isEmpty ? nil : totalChildrenHeight
            
            return (
                contents: Size(width: maxChildWidth,
                               height: possibleHeight),
                intrinsic: Size(width: nil, height: nil)
            )
        case .row:
            
            // calculate the innersize of the flex view when the subviews are positioned horizontally
            
            // get the total width of all the children.
            // also get the maxWidth of all the children (if they are not flexibly sized)
            let (totalChildrenWidth, maxChildHeight) = childSizers
                .reduce((Double(0), Optional<Double>.none)) {
                    
                    let childDims = $1(viewDimensions)
                    
                    var maxHeight = $0.1
                    // only use the child's outersize if it has concrete contents size
                    if childDims.contentsSize.height != nil {
                        maxHeight = max(maxHeight ?? 0, childDims.outerSize.height)
                    }
                    
                    return (
                        totalWidth: $0.0 + childDims.outerSize.width,
                        maxHeight: maxHeight
                    )
            }
            
            // if the view has children then use the totalHeight, otherwise not height
            let possibleWidth: Double? = childSizers.isEmpty ? nil : totalChildrenWidth
            
            return (
                contents: Size(width: possibleWidth,
                               height: maxChildHeight),
                intrinsic: Size(width: nil, height: nil)
            )
        }
    }
}

// MARK: - Child Sizers

/**
 Generates a function that will produce the size of a view that is within a block view.
 The size of this view's children are used to calculate the height if there is no specific height.
 */
func blockChildSizer(
    layoutProperties: LayoutProperties,
    contentsSizer: @escaping ViewContentsSizer
    ) -> ViewSizer {
    return { containerDimensions in
        
        // make absolute versions of the layout properties based on the parentSize
        var viewDimensions = AbsoluteViewDimensions(
            size: .zero,
            intrinsicSize: Size(width: nil, height: nil),
            contentsSize: Size(width: nil, height: nil),
            layout: AbsoluteLayoutProperties(layoutProperties, in: containerDimensions.innerSize)
        )
        
        let concreteWidth = viewDimensions.layout.size.width
        let concreteHeight = viewDimensions.layout.size.height
        
        // set the size to be either the concrete size or the inner size of the container
        // this is used when calculating the contentsSize
        viewDimensions.size = Size(width: concreteWidth ?? (containerDimensions.innerSize.width - viewDimensions.layout.margins.left - viewDimensions.layout.margins.right),
                                   height: concreteHeight ?? .greatestFiniteMagnitude)
        
        // we dont have absolute dimensions for both height & width - we will need to calculate the contents size
//        if concreteWidth == nil || concreteHeight == nil {
            // calculate & save the size of the contents
            let (possibleContentsSize, intrinsicSize) = contentsSizer(viewDimensions)
            
            // get an concrete version of the contentsSize
            let paddedContentsHeight = (possibleContentsSize.height ?? 0) + viewDimensions.layout.padding.top + viewDimensions.layout.padding.bottom
            
            
            viewDimensions.size = Size(width: concreteWidth ?? viewDimensions.size.width,
                                       height: concreteHeight ?? paddedContentsHeight)
            viewDimensions.intrinsicSize = intrinsicSize
            viewDimensions.contentsSize = possibleContentsSize
//        }
        
//        if let concreteHeight = concreteHeight {
//            viewDimensions.contentsSize.height = concreteHeight - viewDimensions.layout.padding.top - viewDimensions.layout.padding.bottom
//        }
//
//        if let concreteWidth = concreteWidth {
//            viewDimensions.contentsSize.width = concreteWidth - viewDimensions.layout.padding.left - viewDimensions.layout.padding.right
//        }
        
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
 Generates a function that will produce the size of a view that is _within_ an AbsoluteLayout view.
 */
func absoluteChildSizer(
    layoutProperties: LayoutProperties,
    contentsSizer: @escaping ViewContentsSizer
    ) -> ViewSizer {
    return { containerDimensions in
        
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
            if let w = viewDimensions.layout.size.width {
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
            if let h = viewDimensions.layout.size.height {
                return h
            }
            
            // the layout is absolute, and it has a top && bottom position, use them to calculate width
            if let top = viewDimensions.layout.position.top, let bottom = viewDimensions.layout.position.bottom {
                return containerDimensions.size.height - top - bottom - viewDimensions.layout.margins.top - viewDimensions.layout.margins.bottom
            }
            
            return nil
        }()

        // set the size to be either the concrete size or the inner size of the container
        // this is used when calculating the contentsSize
        viewDimensions.size = Size(width: concreteWidth ?? containerDimensions.innerSize.width,
                                   height: concreteHeight ?? containerDimensions.innerSize.height)
        
        // we dont have absolute dimensions for both height & width - we will need to calculate the contents size
//        if concreteWidth == nil || concreteHeight == nil {
            let (possibleContentsSize, intrinsicSize) = contentsSizer(viewDimensions)
            
            // get an concrete version of the contentsSize
            let paddedContentsSize = Size(
                width: (possibleContentsSize.width ?? 0) + viewDimensions.layout.padding.left + viewDimensions.layout.padding.right,
                height: (possibleContentsSize.height ?? 0) + viewDimensions.layout.padding.top + viewDimensions.layout.padding.bottom
            )
            
            viewDimensions.size = Size(width: concreteWidth ?? paddedContentsSize.width,
                                       height: concreteHeight ?? paddedContentsSize.height)
            viewDimensions.intrinsicSize = intrinsicSize
            viewDimensions.contentsSize = possibleContentsSize
//        }
//
//        if let concreteHeight = concreteHeight {
//            viewDimensions.contentsSize.height = concreteHeight - viewDimensions.layout.padding.top - viewDimensions.layout.padding.bottom
//        }
//
//        if let concreteWidth = concreteWidth {
//            viewDimensions.contentsSize.width = concreteWidth - viewDimensions.layout.padding.left - viewDimensions.layout.padding.right
//        }
        
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
 Given a sized view,
 */
func flexChildSizeTweaker(
    flexProperties: FlexLayoutProperties,
    normalizedFlexGrow: Double
    ) -> ViewSizeTweaker {
    return { viewDims, containerDims, prevSiblings, nextSiblings in
        switch flexProperties.direction {
        case .column:
            let totalContentHeight: Double = viewDims.outerSize.height + prevSiblings.reduce(0, { $0 + $1.outerSize.height }) + nextSiblings.reduce(0, { $0 + $1.outerSize.height })
            
            let freeHeight = containerDims.innerSize.height - totalContentHeight
            
            let additionalHeight = normalizedFlexGrow * freeHeight
            
            var tweakedViewDims = viewDims
            tweakedViewDims.size.height += additionalHeight
            
            return tweakedViewDims
        case .row:
            let totalContentWidth: Double = viewDims.outerSize.width + prevSiblings.reduce(0, { $0 + $1.outerSize.width }) + nextSiblings.reduce(0, { $0 + $1.outerSize.width })
            
            let freeWidth = containerDims.innerSize.width - totalContentWidth
            
            let additionalWidth = normalizedFlexGrow * freeWidth
            
            var tweakedViewDims = viewDims
            tweakedViewDims.size.width += additionalWidth
            
            return tweakedViewDims
        }
    }
}

/**
 Generates a function that will produce the size of a view that is _within_ a FlexLayout view.
 */
func flexChildSizer(
    flexProperties: FlexLayoutProperties,
    layoutProperties: LayoutProperties,
    normalizedGrow: Double?,
    contentsSizer: @escaping ViewContentsSizer
    ) -> ViewSizer {
    return { containerDimensions in
        
        // make absolute versions of the layout properties based on the parentSize
        var viewDimensions = AbsoluteViewDimensions(
            size: .zero,
            intrinsicSize: Size(width: nil, height: nil),
            contentsSize: Size(width: nil, height: nil),
            layout: AbsoluteLayoutProperties(layoutProperties, in: containerDimensions.innerSize)
        )
        
        // does the view have specific width & height
        let concreteSize = Size(width: viewDimensions.layout.size.width,
                                height: viewDimensions.layout.size.height)
        
        // set the size to be either the concrete size or the inner size of the container
        // this is used when calculating the contentsSize
        viewDimensions.size = Size(width: concreteSize.width ?? containerDimensions.innerSize.width,
                                   height: concreteSize.height ?? containerDimensions.innerSize.height)
        
        // we dont have concrete dimensions for both height & width - we will need to calculate the contents size
//        if concreteSize.width == nil || concreteSize.height == nil {
            let (possibleContentsSize, intrinsicSize) = contentsSizer(viewDimensions)
            
            // get an concrete version of the contentsSize
            let paddedContentsSize = Size(
                width: (possibleContentsSize.width ?? 0) + viewDimensions.layout.padding.left + viewDimensions.layout.padding.right,
                height: (possibleContentsSize.height ?? 0) + viewDimensions.layout.padding.top + viewDimensions.layout.padding.bottom
            )
            // for some reason, when in a flex-view, the size is the max of concrete size & padded size
            viewDimensions.size = Size(width: max((concreteSize.width ?? 0), paddedContentsSize.width),
                                       height: max((concreteSize.height ?? 0), paddedContentsSize.height))
            viewDimensions.intrinsicSize = intrinsicSize
            viewDimensions.contentsSize = possibleContentsSize
//        }
//
//        if let concreteHeight = concreteSize.height {
//            viewDimensions.contentsSize.height = concreteHeight - viewDimensions.layout.padding.top - viewDimensions.layout.padding.bottom
//        }
//
//        if let concreteWidth = concreteSize.width {
//            viewDimensions.contentsSize.width = concreteWidth - viewDimensions.layout.padding.left - viewDimensions.layout.padding.right
//        }
        
        // we now have viewDimensions that are based on the view's contents/intrinsic size etc
        // now we need to apply the flex-layout to those dimensions
        
        // TODO: use flex-basis / flex-grow / flex-shrink etc here...
        switch flexProperties.direction {
        case .column:
            if flexProperties.itemAlignment == .stretch,
                viewDimensions.contentsSize.width == nil {
                // if it doesnt have specific content size when stretching we fill container
                viewDimensions.size.width = containerDimensions.innerSize.width - viewDimensions.layout.margins.left - viewDimensions.layout.margins.right
            }
            
            let freeHeight = containerDimensions.innerSize.height - (containerDimensions.contentsSize.height ?? 0)
//            print(freeHeight, freeHeight * (normalizedGrow ?? 0), containerDimensions.size, containerDimensions.contentsSize, normalizedGrow, viewDimensions.size, viewDimensions.size.height + (freeHeight * (normalizedGrow ?? 0)))
            
            viewDimensions.size.height += freeHeight * (normalizedGrow ?? 0)
            
            
        case .row:
            if flexProperties.itemAlignment == .stretch,
                viewDimensions.contentsSize.height == nil {
                // if it doesnt have specific content size when stretching we fill container
                viewDimensions.size.height = containerDimensions.innerSize.height - viewDimensions.layout.margins.top - viewDimensions.layout.margins.bottom
            }
        }
        
        return viewDimensions
    }
}

// MARK: - Child Positioners

/**
 Generates a function that will produce the position of a view that is the child of a Block view.
 */
func blockChildPositioner(gravity: HorizontalGravity) -> ViewPositioner {
    return { viewDims, containerDims, prevSiblings, _ in
        
        let originY: Double = {
            
            let (totalPrevSiblingHeight, prevBottomMargin) = prevSiblings.reduce((Double(0), Double(0))) { res, prevSibling in
                return (
                    res.0 + prevSibling.outerSize.height - min(prevSibling.layout.margins.top, res.1),
                    prevSibling.layout.margins.bottom
                )
            }
            
            return containerDims.layout.padding.top + (containerDims.intrinsicSize.height ?? 0) + totalPrevSiblingHeight + viewDims.layout.margins.top - min(prevBottomMargin, viewDims.layout.margins.top)
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
    return { viewDims, containerDims, _, _ in
        
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
 In this case, `containerDims` will be the FlexLayout view's dimensions.
 */
func flexChildPositioner(flexProperties: FlexLayoutProperties) -> ViewPositioner {
    return { viewDims, containerDims, prevSiblings, nextSiblings in
        
        switch flexProperties.direction {
        case .row:
            return flexChildRowPosition(
                viewDims: viewDims,
                containerDims: containerDims,
                prevSiblings: prevSiblings,
                nextSiblings: nextSiblings,
                justification: flexProperties.contentJustification,
                itemAlignment: flexProperties.itemAlignment
            )
            
        case .column:
            return flexChildColumnPosition(
                viewDims: viewDims,
                containerDims: containerDims,
                prevSiblings: prevSiblings,
                nextSiblings: nextSiblings,
                justification: flexProperties.contentJustification,
                itemAlignment: flexProperties.itemAlignment
            )
        }
    }
}

/**
 Generates the location of a FlexLayout child view when it is in a row.
 */
func flexChildRowPosition(
    viewDims: AbsoluteViewDimensions,
    containerDims: AbsoluteViewDimensions,
    prevSiblings: [AbsoluteViewDimensions],
    nextSiblings: [AbsoluteViewDimensions],
    justification: FlexLayoutProperties.ContentJustification,
    itemAlignment: FlexLayoutProperties.ItemAlignment
    ) -> Point<Double> {
    
    let originX: Double = {
        switch justification {
        case .center:
            let containerInnerWidth = containerDims.innerSize.width
            
            let totalPrevSiblingWidth = prevSiblings.reduce(0, { $0 + $1.outerSize.width })
            let totalSiblingWidth = nextSiblings.reduce(viewDims.outerSize.width, { $0 + $1.outerSize.width }) + totalPrevSiblingWidth
            
            let initialSpace = (containerInnerWidth - totalSiblingWidth) / 2
            
            return containerDims.layout.padding.left + initialSpace + totalPrevSiblingWidth + viewDims.layout.margins.left
            
        case .flexStart:
            let totalPrevWidth = prevSiblings.reduce(0, { $0 + $1.outerSize.width })
            
            return containerDims.layout.padding.left + totalPrevWidth + viewDims.layout.margins.left
            
        case .flexEnd:
            
            // the width of all the following views
            let totalTrailingWidth = nextSiblings.reduce(viewDims.outerSize.width, { $0 + $1.outerSize.width
            })
            
            return containerDims.size.width - containerDims.layout.padding.right - totalTrailingWidth + viewDims.layout.margins.left
            
        case .spaceBetween:
            let containerInnerWidth = containerDims.innerSize.width
            
            let totalPrevSiblingWidth = prevSiblings.reduce(0, { $0 + $1.outerSize.width })
            
            let totalSiblingWidth = nextSiblings.reduce(viewDims.outerSize.width, { $0 + $1.outerSize.width }) + totalPrevSiblingWidth
            
            let remainingSpace = containerInnerWidth - totalSiblingWidth
            
            let numberOfSpaces = nextSiblings.count + prevSiblings.count
            
            let space = numberOfSpaces > 0 ? remainingSpace / Double(numberOfSpaces) : 0
            
            let numberPrevSpaces = prevSiblings.count
            
            return containerDims.layout.padding.left + viewDims.layout.margins.left + totalPrevSiblingWidth + (space * Double(numberPrevSpaces))
            
        case .spaceAround:
            let containerInnerWidth = containerDims.innerSize.width
            
            let totalPrevSiblingWidth = prevSiblings.reduce(0, { $0 + $1.outerSize.width })
            
            let totalSiblingWidth = nextSiblings.reduce(viewDims.outerSize.width, { $0 + $1.outerSize.width }) + totalPrevSiblingWidth
            
            let remainingSpace = containerInnerWidth - totalSiblingWidth
            
            let numberOfSpaces = (nextSiblings.count + prevSiblings.count + 1) * 2
            
            let space = numberOfSpaces > 0 ? remainingSpace / Double(numberOfSpaces) : 0
            
            let numberPrevSpaces = (prevSiblings.count * 2) + 1
            
            return containerDims.layout.padding.left + viewDims.layout.margins.left + totalPrevSiblingWidth + (space * Double(numberPrevSpaces))
        }
    }()
    
    let originY: Double = {
        switch itemAlignment {
        case .center:
            return containerDims.layout.padding.top + (containerDims.innerSize.height / 2) - (viewDims.outerSize.height / 2) + viewDims.layout.margins.top
        case .stretch,
             .flexStart,
             .baseline:
            return containerDims.layout.padding.top + viewDims.layout.margins.top
        case .flexEnd:
            return containerDims.size.height - containerDims.layout.padding.bottom - viewDims.layout.margins.bottom - viewDims.size.height
        }
    }()
    
    return Point(
        x: originX,
        y: originY
    )
}

/**
 Generates the location of a FlexLayout child view when it is in a row.
 */
func flexChildColumnPosition(
    viewDims: AbsoluteViewDimensions,
    containerDims: AbsoluteViewDimensions,
    prevSiblings: [AbsoluteViewDimensions],
    nextSiblings: [AbsoluteViewDimensions],
    justification: FlexLayoutProperties.ContentJustification,
    itemAlignment: FlexLayoutProperties.ItemAlignment
    ) -> Point<Double> {
    
    let originY: Double = {
        switch justification {
        case .center:
            let containerInnerHeight = containerDims.innerSize.height
            
            let totalPrevSiblingHeight = prevSiblings.reduce(0, { $0 + $1.outerSize.height })
            let totalSiblingHeight = nextSiblings.reduce(viewDims.outerSize.height, { $0 + $1.outerSize.height }) + totalPrevSiblingHeight
            
            let initialSpace = (containerInnerHeight - totalSiblingHeight) / 2
            
            return containerDims.layout.padding.top + initialSpace + totalPrevSiblingHeight + viewDims.layout.margins.top
            
        case .flexStart:
            let totalPrevHeight = prevSiblings.reduce(0, { $0 + $1.outerSize.height })
            
            return containerDims.layout.padding.top + totalPrevHeight + viewDims.layout.margins.top
            
        case .flexEnd:
            
            // the height of all the following views
            let totalTrailingHeight = nextSiblings.reduce(viewDims.outerSize.height, { $0 + $1.outerSize.height
            })
            
            return containerDims.size.height - containerDims.layout.padding.bottom - totalTrailingHeight + viewDims.layout.margins.top
            
        case .spaceBetween:
            let containerInnerHeight = containerDims.innerSize.height
            
            let totalPrevSiblingHeight = prevSiblings.reduce(0, { $0 + $1.outerSize.height })
            
            let totalSiblingHeight = nextSiblings.reduce(viewDims.outerSize.height, { $0 + $1.outerSize.height }) + totalPrevSiblingHeight
            
            let remainingSpace = containerInnerHeight - totalSiblingHeight
            
            let numberOfSpaces = nextSiblings.count + prevSiblings.count
            
            let space = numberOfSpaces > 0 ? remainingSpace / Double(numberOfSpaces) : 0
            
            let numberPrevSpaces = prevSiblings.count
            
            return containerDims.layout.padding.top + viewDims.layout.margins.top + totalPrevSiblingHeight + (space * Double(numberPrevSpaces))
            
        case .spaceAround:
            let containerInnerHeight = containerDims.innerSize.height
            
            let totalPrevSiblingHeight = prevSiblings.reduce(0, { $0 + $1.outerSize.height })
            
            let totalSiblingHeight = nextSiblings.reduce(viewDims.outerSize.height, { $0 + $1.outerSize.height }) + totalPrevSiblingHeight
            
            let remainingSpace = containerInnerHeight - totalSiblingHeight
            
            let numberOfSpaces = (nextSiblings.count + prevSiblings.count + 1) * 2
            
            let space = numberOfSpaces > 0 ? remainingSpace / Double(numberOfSpaces) : 0
            
            let numberPrevSpaces = (prevSiblings.count * 2) + 1
            
            return containerDims.layout.padding.top + viewDims.layout.margins.top + totalPrevSiblingHeight + (space * Double(numberPrevSpaces))
        }
    }()
    
    let originX: Double = {
        switch itemAlignment {
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

// MARK: Resolve Layouts -

//typealias ContentSizer = (AbsoluteViewDimensions) -> Size<Double?>
//
//extension TreeNode where T == (ViewProperties, ContentSizer) {
//    func calculate(in rootSize: Size<Double>) -> TreeNode<(view: ViewProperties, dimensions: AbsoluteViewDimensions, position: Point<Double>)> {
//
//        // first calculate all the contentSizes
//
////    func calculateContentSize(in containerDimensions: AbsoluteViewDimensions) -> TreeNode<(ViewProperties, Size<Double?>)> {
//
//
//
//        //    let childContentSizes
//        for child in self.children {
//
//        }
////        return Size(width: nil, height: nil)
//    }
//}

extension TreeNode where T == (ViewProperties, ViewLayouter) {
    func resolve(rootSize: Size<Double>) -> TreeNode<(view: ViewProperties, dimensions: AbsoluteViewDimensions, position: Point<Double>)> {
        
        let rootContainerDimensions = AbsoluteViewDimensions(
            size: rootSize,
            intrinsicSize: Size(width: nil, height: nil),
            contentsSize: Size(width: nil, height: nil),
            layout: AbsoluteLayoutProperties(.empty, in: rootSize)
        )
        
        let sizedTree: TreeNode<(view: ViewProperties, layouter: ViewLayouter, dimensions: AbsoluteViewDimensions)> = self.mapTree { viewNode, newParent in
            
            let (viewProperties, viewLayouter) = viewNode.value
            
            let containerDimensions = newParent?.value.dimensions ?? rootContainerDimensions
            
            // use the container dimensions to calculate the child's dimensions
            let viewDimensions = viewLayouter.sizer(containerDimensions)
            
            return (view: viewProperties,
                    layouter: viewLayouter,
                    dimensions: viewDimensions)
        }
        
        let tweakedSizedTree: TreeNode<(view: ViewProperties, layouter: ViewLayouter, dimensions: AbsoluteViewDimensions)> = sizedTree.mapTree { viewNode, newParent in
            
            let (viewProperties, viewLayouter, viewDimensions) = viewNode.value

            // only map if it has a sizeTweaker
            guard let sizeTweaker = viewLayouter.sizeTweaker else {
                return viewNode.value
            }
            
            let containerDimensions = newParent?.value.dimensions ?? rootContainerDimensions
            
            let (prevSiblings, nextSiblings) = viewNode.mappedGroupedSiblings({ $0.value.dimensions })
            
            let tweakedDimensions = sizeTweaker(
                viewDimensions,
                containerDimensions,
                prevSiblings,
                nextSiblings
            )
            
            return (view: viewProperties,
                    layouter: viewLayouter,
                    dimensions: tweakedDimensions)
        }
        
        return tweakedSizedTree.mapTree { viewNode, newParent in
            
            let (viewProperties, viewLayouter, viewDimensions) = viewNode.value
            
            let containerDimensions = newParent?.value.dimensions ?? rootContainerDimensions
            
            // get the dimensions of the preceding & following siblings
            let (prevSiblings, nextSiblings) = viewNode.mappedGroupedSiblings({ $0.value.dimensions })
            
            let viewPosition = viewLayouter.positioner(
                viewDimensions,
                containerDimensions,
                prevSiblings,
                nextSiblings
            )
            
            return (viewProperties, viewDimensions, viewPosition)
        }
    }
}


//struct ContentSize {
//
//    private let sizer: (AbsoluteViewDimensions) -> Size<Double?>
//    private var cache: (input: AbsoluteViewDimensions, res: Size<Double?>)? = nil
//
//    mutating func contentSize(for containerDimensions: AbsoluteViewDimensions) -> Size<Double?> {
//        if let cache = self.cache, cache.input == containerDimensions {
//            return cache.res
//        }
//
//        result = (containerDimensions, sizer(containerDimensions))
//        return result
//    }
//
//    init(result: Size<Double?>? = nil, sizer: (AbsoluteViewDimensions) -> Size<Double?>) {
//        self.sizer = sizer
//        self.result = result
//    }
//}

//extension TreeNode where T == ViewProperties {
//    func resolve(rootSize: Size<Double>) -> TreeNode<(view: ViewProperties, dimensions: AbsoluteViewDimensions, position: Point<Double>)> {
//
//        // for each child in the
//
//        for child in self.children {
//
//        }
//
//    }
//
//    func calculateContentSize(in)
//}



/*
 # The Layout phase
 
 Starting at the root:
 
 "pass-1": Calculate a contents-size (the node's 'intrinsic' size, based on it's children, and rough parental constraints)
 - calculate a node's rough-size (combine concrete-size and/or parent's rough-size). No child size used. root-node's parent-size is the screen size.
 - calculate the intrinsic-size (eg. the actual contents of the node, like text), based on the rough-size.
 - use that rough-size to calculate the contents-sizes (the size of the child based on only its own content) of all the child-nodes. do this by calling "pass-1" recursively on all each child (this can be done in parallel).
 - calculate the node's contents size, based on the children's contents-sizes, the node's rough-size & concrete-size, and the parent's rough-size.
 - return the rough-size, concrete-size, intrinsic-size, and contents-size, of the node
 
 "pass-2": Calculate the actual size of each node's children.
 - calculate the actual-size (size taking into account parent's actual-size, sibling's content-sizes, and the node's rough-size/contents-size etc) of all of a node's children. We need the node's actual size to be passed into this function. For the very first node, we can use the screen's size as the actual-size.
    - Once a child's actual-size is known, call "pass-2" recursively on that child using the newly found actual-size. This can be done in parallel.
 - calculate the positions of all the node's children.
 - return the actual-size & position
 
*/

struct PassOneResult {
    var concreteSize: Size<Double?>
    var roughSize: Size<Double?>
    var intrinsicSize: Size<Double?>
    var contentsSize: Size<Double?>
    var layout: AbsoluteLayoutProperties
    
    /// The most likely size, given all the available dimensions.
    var possibleSize: Size<Double?> {
        let height: Double? = {
            if concreteSize.height != nil {
                return concreteSize.height
            }
            
            if let contentsHeight = contentsSize.height {
                return contentsHeight + layout.padding.top + layout.padding.bottom
            }
            
            return roughSize.height
        }()
        let width: Double? = {
            if concreteSize.width != nil {
                return concreteSize.width
            }
            
            if let contentsWidth = contentsSize.width {
                return contentsWidth + layout.padding.left + layout.padding.right
            }
            
            return roughSize.width
        }()
        return Size(width: width, height: height)
    }
}

//struct RoughNodeSize {
//    var size: Size<Double?>
//    var padding: Edges<Double>
//
//    // size minus padding
//    var innerSize: Size<Double?> {
//        var innerSize = self.size
//        if let w = innerSize.width {
//            innerSize.width = w - padding.left - padding.right
//        }
//        if let h = innerSize.height {
//            innerSize.height = h - padding.top - padding.bottom
//        }
//        return innerSize
//    }
//}


extension TreeNode where T == ViewProperties {
    
    func layout(
        rootSize: Size<Double>,
        intrinsicSizerBuilder: @escaping (ViewProperties) -> IntrinsicSizer
        ) -> TreeNode<(ViewProperties, PassOneResult, Size<Double>, Point<Double>)> {

        var wrapperLayout = LayoutProperties.empty
        wrapperLayout.width = .unit(.pts(rootSize.width))
        wrapperLayout.gravity = .center

        let wrapperNode = TreeNode<ViewProperties>(
            value: ViewProperties(
                id: .generate(),
                name: nil,
                type: .view,
                style: .empty,
                layout: wrapperLayout
            )
        )
        
        wrapperNode.add(child: self)
        
        let contentSizedTree = wrapperNode.pass1(
            parentRoughInnerSize: Size(width: rootSize.width, height: rootSize.height),
            parentLayoutType: .block,
            intrinsicSizerBuilder: intrinsicSizerBuilder
        )
        
        // TODO: maybe need a node inbetween?
        
        let actualSizedTree = contentSizedTree.sizingPass(actualSize: rootSize)
        
        // TODO: maybe need input position?
        let positionedTree = actualSizedTree.positioningPass(position: .zero)
        
//        let debugTree = positionedTree.mapValues { value, _, idx in
//            "\(idx)) \(value.0.name ?? "?"): [ pos: \(value.3), size: \(value.2), concrete: \(value.1.concreteSize), rough \(value.1.roughSize), intrinsic \(value.1.intrinsicSize), contents \(value.1.contentsSize) ]"
//        }
//
//        print("\(debugTree)")
        
        return positionedTree.children.first!
    }
    
    /**
     Performs the first-pass on the the tree, generating a new tree containing all the properties we will need to calculate the actual size in the next pass.
     
     - parameter parentRoughInnerSize: The inner-size of the parent, if known.
     - parameter parentLayoutType: The node's parent's layout type (block/abs/flex)
     - parameter intrinsicSizerBuilder: A function that returns a function that returns the intrinsic-size of the view (This is the actual contents (not the children) of the node, eg. text size). This allows for injection of a function that depends on platform-specific implementations.
     */
    func pass1(
        parentRoughInnerSize: Size<Double?>,
        parentLayoutType: LayoutType,
        intrinsicSizerBuilder: @escaping (ViewProperties) -> IntrinsicSizer
        ) -> TreeNode<(ViewProperties, PassOneResult)> {
        
        // TODO: CLAMP TO max/min sizes
        
        // make the view's layout properties absolute (in relation to the parent's inner-size)
        let absoluteLayoutProperties = AbsoluteLayoutProperties(
            self.value.layout,
            in: parentRoughInnerSize.unwrapped(width: 0, height: 0)
        )
        
        // calculate concrete-size (depends on node's layout-type)
        let concreteSize = calculateConcreteSize(
            parentLayoutType: parentLayoutType,
            parentSize: parentRoughInnerSize,
            layoutSize: absoluteLayoutProperties.size,
            layoutPosition: absoluteLayoutProperties.position,
            layoutMargins: absoluteLayoutProperties.margins
        )
        
        // calculate a node's rough-size (combine concrete-size and/or parent's rough-size). No child size used.
        let roughSize = calculateRoughSize(
            parentLayoutType: parentLayoutType,
            parentRoughInnerSize: parentRoughInnerSize,
            concreteSize: concreteSize,
            layoutMargins: absoluteLayoutProperties.margins
        )
        
        // when calculating the child-nodes, we need the rough inner-size.
        let roughInnerSize = roughSize.inset(absoluteLayoutProperties.padding)
        
        // calculate the intrinsic-size (eg. the actual contents of the node, like text), constrained to the rough-inner-size.
        // depends on the injected 'intrinsicSizerBuilder', which depends on the node's viewProperties
        let intrinsicSize = intrinsicSizerBuilder(self.value)(roughInnerSize)
        
        // use that rough-size to calculate the contents-sizes (the size of the child based on only its own content) of all the child-nodes. do this by calling "pass-1" recursively on all each child (this could be done in parallel).
        let childNodes = self.children.map {
            $0.pass1(
                parentRoughInnerSize: roughInnerSize,
                parentLayoutType: self.value.type.layoutType,
                intrinsicSizerBuilder: intrinsicSizerBuilder
            )
        }
        
        // calculate the node's contents size, based on the node's rough-size & concrete-size, the children's contents-sizes, and the parent's rough-size.
        // depends on the node's layout-type
        let contentsSize = calculateContentsSize(
            layoutType: self.value.type.layoutType,
            intrinsicSize: intrinsicSize,
            childDimensions: childNodes.map { $0.value.1 }
        )
        
        // return the rough-size, concrete-size, intrinsic-size, and contents-size, of the node
        let result = PassOneResult(
            concreteSize: concreteSize,
            roughSize: roughSize,
            intrinsicSize: intrinsicSize,
            contentsSize: contentsSize,
            layout: absoluteLayoutProperties
        )
        
        let newNode = TreeNode<(ViewProperties, PassOneResult)>(value: (self.value, result))
        newNode.add(children: childNodes)
        
        return newNode
    }
}

/**
 Calculate the 'concrete' size of a view. This is the size that is defined in the layout properties (size/position). It is excluding margins, but including padding).
 
 - parameter layoutSize: The view's size, as defined in the layout properties.
 - parameter layoutPosition: The view's possible position, as defined in the layout properties. Only used when absolutely positioned.
 - parameter layoutMargins: The view's margins, as defined in the layout properties.
 - parameter parentLayoutType: The view's parent's layout type (block/abs/flex)
 - parameter parentSize: The rough size of the parent (excluding margins, including padding, so not inner or outer-size)
 */
func calculateConcreteSize(parentLayoutType: LayoutType, parentSize: Size<Double?>, layoutSize: Size<Double?>, layoutPosition: Edges<Double?>, layoutMargins: Edges<Double>) -> Size<Double?> {
    
    switch parentLayoutType {
    case .block,
         .flex:
        return layoutSize
    case .absolute:
        // find the width specified in the layout properties, or nil if no width specified
        let concreteWidth: Double? = {
            // there is a specific width in the layout properties, so use it
            if let w = layoutSize.width {
                return w
            }
            
            // the layout is absolute, and it has a left && right position, use them to calculate width
            if let left = layoutPosition.left, let right = layoutPosition.right {
                // What if parent has no width?
                return (parentSize.width ?? 0) - left - right - layoutMargins.left - layoutMargins.right
            }
            
            return nil
        }()
        
        // find the height specified in the layout properties, or nil if no width specified
        let concreteHeight: Double? = {
            // there is a specific height in the layout constraints, so use it
            if let h = layoutSize.height {
                return h
            }
            
            // the layout is absolute, and it has a top && bottom position, use them to calculate width
            if let top = layoutPosition.top, let bottom = layoutPosition.bottom {
                // What if parent has no height?
                return (parentSize.height ?? 0) - top - bottom - layoutMargins.top - layoutMargins.bottom
            }
            
            return nil
        }()
        
        return Size<Double?>(width: concreteWidth,
                             height: concreteHeight)
    }
}

/**
 Calculate the 'rough' size of a view. This is how big we think a view is, only taking into account the parent's size, not any of the children's sizes. Basically, this is the constraint used for calculating the content size.
 
 - parameter parentLayoutType: The view's parent's layout type (block/abs/flex)
 - parameter parentRoughInnerSize: The rough-size of the parent, minus the parent's padding.
 - parameter concreteSize: The size of the view as defined solely by the layout properties.
 - parameter margins: The margins of the view.
 */
func calculateRoughSize(parentLayoutType: LayoutType, parentRoughInnerSize: Size<Double?>, concreteSize: Size<Double?>, layoutMargins: Edges<Double>) -> Size<Double?> {
    switch parentLayoutType {
    case .block:
        // set the size to be either the concrete size or the parent's inner size (minus the view's margins)
        // we only do use the parent-size for the width, not the height (as the block's final height is defined by the content)
        return Size(
            width: concreteSize.width ?? parentRoughInnerSize.inset(layoutMargins).width,
            height: concreteSize.height
        )
    case .absolute,
         .flex:
        // set the size to be either the concrete size or the parent's inner size.
        return Size(
            width: concreteSize.width ?? parentRoughInnerSize.width,
            height: concreteSize.height ?? parentRoughInnerSize.height
        )
    }
}

/**
 Calculate the 'contents' size of a view. This is based on the sizes of all the child-nodes. This is the 'inner-size' of the view.
 */
func calculateContentsSize(layoutType: LayoutType, intrinsicSize: Size<Double?>, childDimensions: [PassOneResult]) -> Size<Double?> {
    switch layoutType {
    case .absolute:
        return Size(width: nil, height: nil)
    case .block:
        return calculateBlockContentsSize(
            intrinsicSize: intrinsicSize,
            childDimensions: childDimensions
        )
    case .flex(let flexProperties):
        return calculateFlexContentsSize(
            flexProperties: flexProperties,
            childDimensions: childDimensions
        )
    }
}

func calculateBlockContentsSize(intrinsicSize: Size<Double?>, childDimensions: [PassOneResult]) -> Size<Double?> {
    
    // make the height equal to the sum of the height of all the children
    // Block-based views do a weird dance with their inter-element margins,
    // where the `max` of the (n-1) view's marginBottom & current view's marginTop
    // is used as the space between
    let (totalChildrenHeight, _, maxChildWidth) = childDimensions
        .reduce((Double(0), Double(0), Optional<Double>.none)) { res, childDims in
            
            var maxWidth = res.2
            
            let childPaddedContentsSize = childDims.contentsSize.inset(childDims.layout.padding.negated)
            
            let childPossibleSize = Size(
                width: childDims.concreteSize.width ?? childPaddedContentsSize.width,
                height: childDims.concreteSize.height ?? childPaddedContentsSize.height
            )
            
            // The child has a contentsSize width... use that to calculate the maxWidth
            if let childContentsWidth = childPossibleSize.width {
                maxWidth = max(
                    maxWidth ?? 0,
                    childContentsWidth + childDims.layout.margins.left + childDims.layout.margins.right
                )
            }
            
            let smallestSpacing = min(res.1, childDims.layout.margins.top)
            
            let outerHeight = (childPossibleSize.height ?? 0)
                + childDims.layout.margins.top + childDims.layout.margins.bottom
            
            return (
                height: res.0 + outerHeight - smallestSpacing,
                prevMargin: childDims.layout.margins.bottom,
                maxWidth: maxWidth
            )
    }
    
    // only if there are children do we unwrap the intrinsic height
    var possibleHeight = intrinsicSize.height
    if !childDimensions.isEmpty {
        possibleHeight = (possibleHeight ?? 0) + totalChildrenHeight
    }
    
    return Size(
        width: intrinsicSize.width ?? maxChildWidth,
        height: possibleHeight
    )
}


func calculateFlexContentsSize(flexProperties: FlexLayoutProperties, childDimensions: [PassOneResult]) -> Size<Double?> {
    // TODO: flex-basis may/will affect this?
    // flex-basis is used when calculating the 'free-space' to share amongst the other siblings
    // it totally replaces the 'concrete' & 'contents' height
    // if there is no 'flex-grow' it is still used as the height of the view.
    // if flex-basis is "auto", then just use the normal sizing method
    // if basis is "0" it acts weird... but for now just treat it like it's a specific size until i learn more
    // if flex-basis is a percentage it is of the parent's size
    
    
    switch flexProperties.direction {
    case .column:
        // calculate the innersize of the flex view when the subviews are positioned vertically
        
        // get the total height of all the children.
        // also get the maxWidth of all the children (if they are not flexibly sized)
        let (totalChildrenHeight, maxChildWidth) = childDimensions
            .reduce((Double(0), Optional<Double>.none)) { res, childDims in
                
                var maxWidth = res.1
                
                let childPaddedContentsSize = childDims.contentsSize.inset(childDims.layout.padding.negated)
                
                let childPossibleSize = Size(
                    width: childDims.concreteSize.width ?? childPaddedContentsSize.width,
                    height: childDims.concreteSize.height ?? childPaddedContentsSize.height
                )
                
                // The child has a contentsSize width... use that to calculate the maxWidth
                if let childContentsWidth = childPossibleSize.width {
                    maxWidth = max(
                        maxWidth ?? 0,
                        childContentsWidth + childDims.layout.margins.left + childDims.layout.margins.right
                    )
                }
                
                let outerHeight = (childPossibleSize.height ?? 0)
                    + childDims.layout.margins.top + childDims.layout.margins.bottom
                
                return (
                    totalHeight: res.0 + outerHeight,
                    maxWidth: maxWidth
                )
        }
        
        // if the view has children then use the totalHeight, otherwise nil height
        return Size(
            width: maxChildWidth,
            height: childDimensions.isEmpty ? nil : totalChildrenHeight
        )
    case .row:
        
        // calculate the innersize of the flex view when the subviews are positioned horizontally
        
        // get the total width of all the children.
        // also get the maxWidth of all the children (if they are not flexibly sized)
        let (totalChildrenWidth, maxChildHeight) = childDimensions
            .reduce((Double(0), Optional<Double>.none)) { res, childDims in
                
                var maxHeight = res.1
                
                let childPaddedContentsSize = childDims.contentsSize.inset(childDims.layout.padding.negated)
                
                let childPossibleSize = Size(
                    width: childDims.concreteSize.width ?? childPaddedContentsSize.width,
                    height: childDims.concreteSize.height ?? childPaddedContentsSize.height
                )
                
                // The child has a contentsSize height... use that to calculate the maxHeight
                if let childContentsHeight = childPossibleSize.height {
                    maxHeight = max(
                        maxHeight ?? 0,
                        childContentsHeight + childDims.layout.margins.top + childDims.layout.margins.bottom
                    )
                }
                
                let outerWidth = (childPossibleSize.width ?? 0)
                    + childDims.layout.margins.left + childDims.layout.margins.right
                
                return (
                    totalWidth: res.0 + outerWidth,
                    maxHeight: maxHeight
                )
        }
        
        // if the view has children then use the totalHeight, otherwise nil height
        return Size(
            width: childDimensions.isEmpty ? nil : totalChildrenWidth,
            height: maxChildHeight
        )
    }
}


extension TreeNode where T == (ViewProperties, PassOneResult) {
    func sizingPass(actualSize: Size<Double>) -> TreeNode<(ViewProperties, PassOneResult, Size<Double>)> {
        
        let newNode = TreeNode<(ViewProperties, PassOneResult, Size<Double>)>(value: (self.value.0, self.value.1, actualSize))
        
        let layoutType = self.value.0.type.layoutType
        let dimensions = self.value.1
        // calculate the actual-size (size taking into account parent's actual-size, sibling's content-sizes, and the node's rough-size/contents-size etc) of all of a node's children. We need the node's actual size to be passed into this function. For the very first node, we can use the screen's size as the actual-size.
        let childNodes: [TreeNode<(ViewProperties, PassOneResult, Size<Double>)>] = self.children.map { child in
            
            let childDimensions = child.value.1
            let childViewProperties = child.value.0
//            let (prevSiblings, nextSiblings) = self.mappedGroupedSiblings()
//            let prevSiblingContentSizes = prevSiblings.map { $0.value.1.contentsSize }
//            let nextSiblingContentSizes = nextSiblings.map { $0.value.1.contentsSize }
            
            let childActualSize = calculateActualSize(
                parentLayoutType: layoutType,
                parentSize: actualSize,
                parentPadding: dimensions.layout.padding,
                parentContentsSize: dimensions.contentsSize,
                dimensions: childDimensions,
                layoutProperties: childViewProperties.layout,
                siblings: child.siblings(excludeSelf: true).map({ $0.value.0.layout })
            )
            
//            (parentLayoutType: layoutType, dimensions: childDimensions)
            
            // Once a child's actual-size is known, call "pass-2" recursively on that child using the newly found actual-size. This can be done in parallel.
            return child.sizingPass(actualSize: childActualSize)
        }
        
        newNode.add(children: childNodes)
        
        // return the actual-size
        return newNode
    }
}

extension TreeNode where T == (ViewProperties, PassOneResult, Size<Double>) {
    func positioningPass(position: Point<Double>) -> TreeNode<(ViewProperties, PassOneResult, Size<Double>, Point<Double>)> {
        
        let newNode = TreeNode<(ViewProperties, PassOneResult, Size<Double>, Point<Double>)>(value: (self.value.0, self.value.1, self.value.2, position))
        
        let layoutType = self.value.0.type.layoutType
        let size = self.value.2
        let dimensions = self.value.1
        
        // calculate the actual-size (size taking into account parent's actual-size, sibling's content-sizes, and the node's rough-size/contents-size etc) of all of a node's children. We need the node's actual size to be passed into this function. For the very first node, we can use the screen's size as the actual-size.
        let childNodes: [TreeNode<(ViewProperties, PassOneResult, Size<Double>, Point<Double>)>] = self.children.map { child in
            
            let childViewProperties = child.value.0
            let childDimensions = child.value.1
            let childSize = child.value.2
            
            let (prevSiblings, nextSiblings) = child.mappedGroupedSiblings({ (size: $0.value.2, dimensions: $0.value.1) })
            
            let childPosition = calculatePosition(
                parentLayoutType: layoutType,
                parentSize: size,
                parentPadding: dimensions.layout.padding,
                parentIntrinsicSize: dimensions.intrinsicSize,
                size: childSize,
                margins: childDimensions.layout.margins,
                position: childDimensions.layout.position,
                layoutProperties: childViewProperties.layout,
                prevSiblings: prevSiblings,
                nextSiblings: nextSiblings
            )
            
            // Once a child's position is known, call "positioningPass" recursively on that child using the newly found position.
            return child.positioningPass(position: childPosition)
        }
        
        newNode.add(children: childNodes)
        
        // return the nodes, including the positioned children
        return newNode
    }
}

// MARK: - Calculate Actual Sizes

/**
 Calculate the 'actual' size of a view. This is the final size of the view, given the size of all the children etc.
 */
func calculateActualSize(parentLayoutType: LayoutType, parentSize: Size<Double>, parentPadding: Edges<Double>, parentContentsSize: Size<Double?>, dimensions: PassOneResult, layoutProperties: LayoutProperties, siblings: [LayoutProperties]) -> Size<Double> {
    switch parentLayoutType {
    case .block:
        return calculateBlockChildActualSize(
            concreteSize: dimensions.concreteSize,
            roughSize: dimensions.roughSize,
            contentsSize: dimensions.contentsSize,
            padding: dimensions.layout.padding
        )
    case .absolute:
        return calculateAbsoluteChildActualSize(
            concreteSize: dimensions.concreteSize,
            contentsSize: dimensions.contentsSize,
            padding: dimensions.layout.padding
        )
    case .flex(let flexProperties):
        return calculateFlexChildActualSize(
            flexProperties: flexProperties,
            concreteSize: dimensions.concreteSize,
            contentsSize: dimensions.contentsSize,
            padding: dimensions.layout.padding,
            margins: dimensions.layout.margins,
            flexGrow: layoutProperties.flexGrow ?? 0,
            siblingFlexGrows: siblings.map({ $0.flexGrow ?? 0 }),
            flexShrink: layoutProperties.flexShrink ?? 1,
            siblingFlexShrinks: siblings.map({ $0.flexShrink ?? 1 }),
            parentSize: parentSize,
            parentPadding: parentPadding,
            parentContentsSize: parentContentsSize
        )
    }
}

func calculateBlockChildActualSize(concreteSize: Size<Double?>, roughSize: Size<Double?>, contentsSize: Size<Double?>, padding: Edges<Double>) -> Size<Double> {
    
    // get an concrete version of the contentsSize
    let paddedContentsHeight = (contentsSize.height ?? 0) + padding.top + padding.bottom
    
    // what about intrinsic height?
    let size = Size(
        width: concreteSize.width ?? roughSize.width ?? 0,
        height: concreteSize.height ?? paddedContentsHeight
    )

    return size
}

func calculateAbsoluteChildActualSize(concreteSize: Size<Double?>, contentsSize: Size<Double?>, padding: Edges<Double>) -> Size<Double> {
    
    let paddedContentsSize = contentsSize.inset(padding.negated)
    
    return Size(
        width: concreteSize.width ?? paddedContentsSize.width ?? 0,
        height: concreteSize.height ?? paddedContentsSize.height ?? 0
    )
}

func calculateFlexChildActualSize(flexProperties: FlexLayoutProperties, concreteSize: Size<Double?>, contentsSize: Size<Double?>, padding: Edges<Double>, margins: Edges<Double>, flexGrow: Double, siblingFlexGrows: [Double], flexShrink: Double, siblingFlexShrinks: [Double], parentSize: Size<Double>, parentPadding: Edges<Double>, parentContentsSize: Size<Double?>) -> Size<Double> {
    
    let paddedContentsSize = contentsSize.inset(padding.negated)
    
    let normalizedGrow: Double = {
        let totalGrow: Double = siblingFlexGrows.reduce(flexGrow, +)
        return totalGrow == 0 ? 0 : flexGrow / totalGrow
    }()
    
    let normalizedShrink: Double = {
        let totalShrink: Double = siblingFlexShrinks.reduce(flexShrink, +)
        return totalShrink == 0 ? 0 : flexShrink / totalShrink
    }()
    
    // for some reason, when in a flex-view, the size is the max of concrete size & padded size
//    let initialSize = Size(
//        width: max((concreteSize.width ?? 0), (paddedContentsSize.width ?? 0)),
//        height: max((concreteSize.height ?? 0), (paddedContentsSize.height ?? 0))
//    )
    
    // we now have viewDimensions that are based on the view's contents/intrinsic size etc
    // now we need to apply the flex-layout to those dimensions
    
    // TODO: use flex-basis / flex-grow / flex-shrink etc here...
    switch flexProperties.direction {
    case .column:
        
        let width: Double = {
            if let concreteWidth = concreteSize.width {
                return concreteWidth
            } else if flexProperties.itemAlignment == .stretch {
                return parentSize
                    .inset(parentPadding)
                    .inset(margins)
                    .width
            } else {
                return paddedContentsSize.width ?? 0
            }
        }()
        
        let height: Double = {
            let actualHeight = concreteSize.height ?? paddedContentsSize.height ?? 0
            
            let freeSpace = parentSize.height - parentPadding.top - parentPadding.bottom - (parentContentsSize.height ?? 0)
            
            // we then need to either size that down or up, depending on flex-grow/shrink
            if freeSpace > 0 {
                return actualHeight + (freeSpace * normalizedGrow)
            } else {
                return actualHeight + (freeSpace * normalizedShrink)
            }
        }()
        
        return Size(
            width: width,
            height: height
        )
        
    case .row:

        let height: Double = {
            if let concreteHeight = concreteSize.height {
                return concreteHeight
            } else if flexProperties.itemAlignment == .stretch {
                return parentSize
                    .inset(parentPadding)
                    .inset(margins)
                    .height
            } else {
                return paddedContentsSize.height ?? 0
            }
        }()
        
        let width: Double = {
            let actualWidth = concreteSize.width ?? paddedContentsSize.width ?? 0
            
            let freeSpace = parentSize.width - parentPadding.left - parentPadding.right - (parentContentsSize.width ?? 0)
            
            // we then need to either size that down or up, depending on flex-grow/shrink
            if freeSpace > 0 {
                return actualWidth + (freeSpace * normalizedGrow)
            } else {
                return actualWidth + (freeSpace * normalizedShrink)
            }
        }()
        
        return Size(
            width: width,
            height: height
        )
    }
}

// MARK: - Calculate Position

func calculatePosition(parentLayoutType: LayoutType, parentSize: Size<Double>, parentPadding: Edges<Double>, parentIntrinsicSize: Size<Double?>, size: Size<Double>, margins: Edges<Double>, position: Edges<Double?>, layoutProperties: LayoutProperties, prevSiblings: [(size: Size<Double>, dimensions: PassOneResult)], nextSiblings: [(size: Size<Double>, dimensions: PassOneResult)]) -> Point<Double> {
    switch parentLayoutType {
    case .block:
        // TODO: different default gravity if system is right-to-left layout
        let gravity = layoutProperties.gravity ?? .left
        return calculateBlockChildPosition(
            parentSize: parentSize,
            parentGravity: gravity,
            parentPadding: parentPadding,
            parentIntrinsicSize: parentIntrinsicSize,
            size: size,
            margins: margins,
            prevSiblings: prevSiblings
        )
    case .absolute:
        return calculateAbsoluteChildPosition(
            size: size,
            position: position,
            margins: margins,
            parentSize: parentSize,
            parentPadding: parentPadding
        )
    case .flex(let flexProperties):
        return calculateFlexChildPosition(
            flexProperties: flexProperties,
            parentSize: parentSize,
            parentPadding: parentPadding,
            prevSiblings: prevSiblings,
            nextSiblings: nextSiblings,
            size: size,
            margins: margins
        )
    }
}

func calculateBlockChildPosition(parentSize: Size<Double>, parentGravity: HorizontalGravity, parentPadding: Edges<Double>, parentIntrinsicSize: Size<Double?>, size: Size<Double>, margins: Edges<Double>, prevSiblings: [(size: Size<Double>, dimensions: PassOneResult)]) -> Point<Double> {
    
    let originY: Double = {
        
        let (totalPrevSiblingHeight, prevBottomMargin) = prevSiblings.reduce((Double(0), Double(0))) { res, prevSibling in
            let margins = prevSibling.dimensions.layout.margins
            let siblingOuterHeight = prevSibling.size.height + margins.top + margins.bottom
            
            return (
                res.0 + siblingOuterHeight - min(margins.top, res.1),
                margins.bottom
            )
        }
        
        return parentPadding.top
            + (parentIntrinsicSize.height ?? 0)
            + totalPrevSiblingHeight
            + margins.top - min(prevBottomMargin, margins.top)
    }()
    
    let originX: Double = {
        switch parentGravity {
        case .left:
            return parentPadding.left + margins.left
        case .right:
            return parentSize.width - parentPadding.right - margins.right - size.width
        case .center:
            
            let parentInnerWidth = parentSize.width - parentPadding.left - parentPadding.right
            let outerWidth = size.width + margins.left + margins.right
            
            return parentPadding.left + (parentInnerWidth / 2) - (outerWidth / 2) + margins.left
        }
    }()
    return Point(
        x: originX,
        y: originY
    )
}

func calculateAbsoluteChildPosition(size: Size<Double>, position: Edges<Double?>, margins: Edges<Double>, parentSize: Size<Double>, parentPadding: Edges<Double>) -> Point<Double> {
    
    let originX: Double = {
        if let left = position.left {
            return left + margins.left
        } else if let right = position.right {
            return parentSize.width - right - margins.right - size.width
        } else {
            return parentPadding.left + margins.left
        }
    }()
    
    let originY: Double = {
        if let top = position.top {
            return top + margins.top
        } else if let bottom = position.bottom {
            return parentSize.height - bottom - margins.bottom - size.height
        } else {
            return parentPadding.top + margins.top
        }
    }()
    
    return Point(
        x: originX,
        y: originY
    )
}

func calculateFlexChildPosition(flexProperties: FlexLayoutProperties, parentSize: Size<Double>, parentPadding: Edges<Double>, prevSiblings: [(size: Size<Double>, dimensions: PassOneResult)], nextSiblings: [(size: Size<Double>, dimensions: PassOneResult)], size: Size<Double>, margins: Edges<Double>) -> Point<Double> {
    switch flexProperties.direction {
    case .row:
        return calculateFlexChildRowPosition(
            justification: flexProperties.contentJustification,
            itemAlignment: flexProperties.itemAlignment,
            parentSize: parentSize,
            parentPadding: parentPadding,
            prevSiblings: prevSiblings,
            nextSiblings: nextSiblings,
            size: size,
            margins: margins
        )
    case .column:
        return calculateFlexChildColumnPosition(
            justification: flexProperties.contentJustification,
            itemAlignment: flexProperties.itemAlignment,
            parentSize: parentSize,
            parentPadding: parentPadding,
            prevSiblings: prevSiblings,
            nextSiblings: nextSiblings,
            size: size,
            margins: margins
        )
    }
}

func calculateFlexChildRowPosition(
    justification: FlexLayoutProperties.ContentJustification,
    itemAlignment: FlexLayoutProperties.ItemAlignment,
    parentSize: Size<Double>,
    parentPadding: Edges<Double>,
    prevSiblings: [(size: Size<Double>, dimensions: PassOneResult)],
    nextSiblings: [(size: Size<Double>, dimensions: PassOneResult)],
    size: Size<Double>,
    margins: Edges<Double>
    ) -> Point<Double> {
    
    let parentInnerSize = parentSize.inset(parentPadding)
    let outerSize = size.inset(margins.negated)
    
    // the width of all the preceding views
    let totalPrevSiblingWidth = prevSiblings.reduce(0, {
        $0 + $1.size.inset($1.dimensions.layout.margins.negated).width
    })
    // the width of all the following views
    let totalTrailingWidth = nextSiblings.reduce(0, {
        $0 + $1.size.inset($1.dimensions.layout.margins.negated).width
    })
    
    let totalSiblingWidth = totalPrevSiblingWidth + outerSize.width + totalTrailingWidth
    
    let originX: Double = {
        switch justification {
        case .center:
            let initialSpace = (parentInnerSize.width - totalSiblingWidth) / 2
            return parentPadding.left + initialSpace + totalPrevSiblingWidth + margins.left
            
        case .flexStart:
            return parentPadding.left + totalPrevSiblingWidth + margins.left
            
        case .flexEnd:
            return parentSize.width - parentPadding.right - totalTrailingWidth - outerSize.width + margins.left
            
        case .spaceBetween:

            let remainingSpace = parentInnerSize.width - totalSiblingWidth
            
            let numberOfSpaces = nextSiblings.count + prevSiblings.count
            
            let space = numberOfSpaces > 0 ? remainingSpace / Double(numberOfSpaces) : 0
            
            let numberPrevSpaces = prevSiblings.count
            
            return parentPadding.left + margins.left + totalPrevSiblingWidth + (space * Double(numberPrevSpaces))
            
        case .spaceAround:
            let remainingSpace = parentInnerSize.width - totalSiblingWidth
            
            let numberOfSpaces = (nextSiblings.count + prevSiblings.count + 1) * 2
            
            let space = numberOfSpaces > 0 ? remainingSpace / Double(numberOfSpaces) : 0
            
            let numberPrevSpaces = (prevSiblings.count * 2) + 1
            
            return parentPadding.left + margins.left + totalPrevSiblingWidth + (space * Double(numberPrevSpaces))
        }
    }()
    
    let originY: Double = {
        switch itemAlignment {
        case .center:
            return parentPadding.top + (parentInnerSize.height / 2) - (outerSize.height / 2) + margins.top
        case .stretch,
             .flexStart,
             .baseline:
            return parentPadding.top + margins.top
        case .flexEnd:
            return parentSize.height - parentPadding.bottom - margins.bottom - size.height
        }
    }()
    
    return Point(
        x: originX,
        y: originY
    )
}

/**
 Generates the location of a FlexLayout child view when it is in a column.
 */
func calculateFlexChildColumnPosition(
    justification: FlexLayoutProperties.ContentJustification,
    itemAlignment: FlexLayoutProperties.ItemAlignment,
    parentSize: Size<Double>,
    parentPadding: Edges<Double>,
    prevSiblings: [(size: Size<Double>, dimensions: PassOneResult)],
    nextSiblings: [(size: Size<Double>, dimensions: PassOneResult)],
    size: Size<Double>,
    margins: Edges<Double>
    ) -> Point<Double> {
    
    let parentInnerSize = parentSize.inset(parentPadding)
    let outerSize = size.inset(margins.negated)
    
    // the height of all the preceding views
    let totalPrevSiblingHeight = prevSiblings.reduce(0, {
        $0 + $1.size.inset($1.dimensions.layout.margins.negated).height
    })
    // the height of all the following views
    let totalTrailingHeight = nextSiblings.reduce(0, {
        $0 + $1.size.inset($1.dimensions.layout.margins.negated).height
    })
    // the combined height of all the views (including their margins)
    let totalSiblingHeight = totalPrevSiblingHeight + outerSize.height + totalTrailingHeight
    
    let originY: Double = {
        switch justification {
        case .center:
            let initialSpace = (parentInnerSize.height - totalSiblingHeight) / 2
            return parentPadding.top + initialSpace + totalPrevSiblingHeight + margins.top
            
        case .flexStart:
            return parentPadding.top + totalPrevSiblingHeight + margins.top
            
        case .flexEnd:
            return parentSize.height - parentPadding.bottom - totalTrailingHeight - outerSize.height + margins.top
            
        case .spaceBetween:
            
            let remainingSpace = parentInnerSize.height - totalSiblingHeight
            
            let numberOfSpaces = nextSiblings.count + prevSiblings.count
            
            let space = numberOfSpaces > 0 ? remainingSpace / Double(numberOfSpaces) : 0
            
            let numberPrevSpaces = prevSiblings.count
            
            return parentPadding.top + margins.top + totalPrevSiblingHeight + (space * Double(numberPrevSpaces))
            
        case .spaceAround:
            let remainingSpace = parentInnerSize.height - totalSiblingHeight
            
            let numberOfSpaces = (nextSiblings.count + prevSiblings.count + 1) * 2
            
            let space = numberOfSpaces > 0 ? remainingSpace / Double(numberOfSpaces) : 0
            
            let numberPrevSpaces = (prevSiblings.count * 2) + 1
            
            return parentPadding.top + margins.top + totalPrevSiblingHeight + (space * Double(numberPrevSpaces))
        }
    }()
    
    let originX: Double = {
        switch itemAlignment {
        case .center:
            return parentPadding.left + (parentInnerSize.width / 2) - (outerSize.width / 2) + margins.left
        case .stretch,
             .flexStart,
             .baseline:
            return parentPadding.left + margins.left
        case .flexEnd:
            return parentSize.width - parentPadding.right - margins.right - size.width
        }
    }()
    
    return Point(
        x: originX,
        y: originY
    )
}
