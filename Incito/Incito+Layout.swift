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

struct ViewLayouter {
    let sizer: ViewSizer
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
        case .flex(let flex):
            return flexContentsSizer(
                id: id,
                flexProperties: flex,
                intrinsicSizer: intrinsicViewSizer(viewProperties),
                childSizers: childLayouterNodes.map { $0.value.1.sizer }
            )
        }
    }()
    
    // the current node's sizer. takes into account the children.
    // depending on the parent type, use different sizing functions for the child
    let sizer: ViewSizer = {
        switch layoutType {
        case .absolute:
            return absoluteChildSizer(
                id: id,
                layoutProperties: viewProperties.layout,
                contentsSizer: contentsSizer
            )
        case .flex(let flexProperties):
            return flexChildSizer(
                id: id,
                flexProperties: flexProperties,
                layoutProperties: viewProperties.layout,
                contentsSizer: contentsSizer
            )
        case .block:
            return blockChildSizer(
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

// MARK: - Contents Sizers

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
func absoluteContentsSizer(
    id: String
    ) -> ViewContentsSizer {
    return { _ in
        return (Size(width: nil, height: nil), Size(width: nil, height: nil))
    }
}

/**
 Generates a function that will produce the size of the contents of a FlexLayout view (not including the view's padding). So basically the `innerSize` of the flexlayout view.
 The size of this view's children are used to calculate the height if there is no specific height.
 */
func flexContentsSizer(
    id: String,
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
    id: String,
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
        
        return viewDimensions
    }
}

/**
 Generates a function that will produce the size of a view that is _within_ an AbsoluteLayout view.
 */
func absoluteChildSizer(
    id: String,
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

        // set the size to be either the concrete size or the inner size of the container
        // this is used when calculating the contentsSize
        viewDimensions.size = Size(width: concreteWidth ?? containerDimensions.innerSize.width,
                                   height: concreteHeight ?? containerDimensions.innerSize.height)
        
        // we dont have absolute dimensions for both height & width - we will need to calculate the contents size
        if concreteWidth == nil || concreteHeight == nil {
            let (possibleContentsSize, intrinsicSize) = contentsSizer(viewDimensions)
            
            // get an concrete version of the contentsSize
            let contentsSize = Size(
                width: (possibleContentsSize.width ?? 0) + viewDimensions.layout.padding.left + viewDimensions.layout.padding.right,
                height: (possibleContentsSize.height ?? 0) + viewDimensions.layout.padding.top + viewDimensions.layout.padding.bottom
            )
            
            viewDimensions.size = Size(width: concreteWidth ?? contentsSize.width,
                                       height: concreteHeight ?? contentsSize.height)
            viewDimensions.intrinsicSize = intrinsicSize
            viewDimensions.contentsSize = possibleContentsSize
        } else {
            viewDimensions.contentsSize = Size(width: concreteWidth, height: concreteHeight)
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
        
        return viewDimensions
    }
}

/**
 Generates a function that will produce the size of a view that is _within_ a FlexLayout view.
 */
func flexChildSizer(
    id: String,
    flexProperties: FlexLayoutProperties,
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
        
        // does the view have specific width & height
        let concreteSize = Size(width: viewDimensions.layout.width,
                                height: viewDimensions.layout.height)
        
        // set the size to be either the concrete size or the inner size of the container
        // this is used when calculating the contentsSize
        viewDimensions.size = Size(width: concreteSize.width ?? containerDimensions.innerSize.width,
                                   height: concreteSize.height ?? containerDimensions.innerSize.height)
        
        // we dont have concrete dimensions for both height & width - we will need to calculate the contents size
        if concreteSize.width == nil || concreteSize.height == nil {
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
        }
        
        if let concreteHeight = concreteSize.height {
            viewDimensions.contentsSize.height = concreteHeight - viewDimensions.layout.padding.top - viewDimensions.layout.padding.bottom
        }
        
        if let concreteWidth = concreteSize.width {
            viewDimensions.contentsSize.width = concreteWidth - viewDimensions.layout.padding.left - viewDimensions.layout.padding.right
        }
        
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

// given a tree of sizers, walk down calculating the actual dimensions
func resolveLayouters(rootNode: TreeNode<(ViewProperties, ViewLayouter)>, rootSize: Size<Double>) -> TreeNode<(view: ViewProperties, dimensions: AbsoluteViewDimensions, position: Point<Double>)> {
    
    let rootContainerDimensions = AbsoluteViewDimensions(
        size: rootSize,
        intrinsicSize: Size(width: nil, height: nil),
        contentsSize: Size(width: nil, height: nil),
        layout: AbsoluteLayoutProperties(.empty, in: rootSize)
    )
    
    let sizedTree: TreeNode<(view: ViewProperties, layouter: ViewLayouter, dimensions: AbsoluteViewDimensions)> = rootNode.mapTree { viewNode, newParent in
        
        let (viewProperties, viewLayouter) = viewNode.value
        
        let containerDimensions = newParent?.value.dimensions ?? rootContainerDimensions
        
        // use the container dimensions to calculate the child's dimensions
        let viewDimensions = viewLayouter.sizer(containerDimensions)
        
        return (view: viewProperties,
                layouter: viewLayouter,
                dimensions: viewDimensions)
    }
    
    return sizedTree.mapTree { viewNode, newParent in
        
        let (viewProperties, viewLayouter, viewDimensions) = viewNode.value
        
        let containerDimensions = newParent?.value.dimensions ?? rootContainerDimensions
        
        // get the dimensions of the preceding & following siblings        
        let allSizedSiblings = viewNode.parent?.children ?? []
        
        var nextSiblings: [AbsoluteViewDimensions] = []
        var prevSiblings: [AbsoluteViewDimensions] = []
        
        if let viewIndex = allSizedSiblings.index(where: { $0 === viewNode}) {
            
            if viewIndex != allSizedSiblings.startIndex {
                let prevIndex = allSizedSiblings.index(before: viewIndex)
                
                prevSiblings = allSizedSiblings[...prevIndex].map({ $0.value.dimensions })
            }
            
            if viewIndex != allSizedSiblings.endIndex {
                let nextIndex = allSizedSiblings.index(after: viewIndex)
                
                nextSiblings = allSizedSiblings[nextIndex...].map({ $0.value.dimensions })
            }
        }
        
        let viewPosition = viewLayouter.positioner(viewDimensions, containerDimensions, prevSiblings, nextSiblings)
        
        return (viewProperties, viewDimensions, viewPosition)
    }
}
