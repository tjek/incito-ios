//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

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
 - return the actual-size
 
 "pass-3": Calculate the positions of each node.
 - for each child, recursively calculate the position using actual size and dimensions calculated in the previous passes.
 */

/**
 The result of performing the layout pass. Each node in the tree
 */
struct ViewLayout {
    var size: Size<Double>
    var position: Point<Double>
    var viewProperties: ViewProperties
    var dimensions: ViewDimensions
    var transform: Transform<Double>
}

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

// MARK: -

struct ResolvedLayoutProperties {
    var position: Edges<Double?>
    var margins: Edges<Double>
    var padding: Edges<Double>

    var maxSize: Size<Double>
    var minSize: Size<Double>

    var size: Size<Double?> // nil if fitting to child
    
    var flexBasisSize: Size<Double>? // nil if auto
}

extension ResolvedLayoutProperties {
    /// parentSize is the container's inner size (size - padding)
    init(_ properties: LayoutProperties, in parentSize: Size<Double>) {
        self.maxSize = Size(
            width: properties.maxWidth?.absolute(in: parentSize.width) ?? .infinity,
            height: properties.maxHeight?.absolute(in: parentSize.height) ?? .infinity
        )
        self.minSize = Size(
            width: properties.minWidth?.absolute(in: parentSize.width) ?? 0,
            height: properties.minHeight?.absolute(in: parentSize.height) ?? 0
        )
        self.size = Size(
            width: properties.width?.absolute(in: parentSize.width),
            height: properties.height?.absolute(in: parentSize.height)
        )
        
        self.position = properties.position.absolute(in: parentSize)
        
        // margins & padding are actually only relative to the width of the parent, not the height
        let widthOnlyParentSize = Size(width: parentSize.width, height: parentSize.width)
        self.margins = properties.margins.absolute(in: widthOnlyParentSize)
        self.padding = properties.padding.absolute(in: widthOnlyParentSize)
        
        switch properties.flexBasis {
        case .auto:
            self.flexBasisSize = nil
        case .value(let unit):
            self.flexBasisSize = Size(
                width: unit.absolute(in: parentSize.width),
                height: unit.absolute(in: parentSize.height)
            )
        }
    }
}

/**
 These are the properties that are calculated for each node in the first layout pass.
 They are used to calculate the actual size of the node in the next pass.
 */

struct ViewDimensions {
    var concreteSize: Size<Double?>
    var roughSize: Size<Double?>
    var intrinsicSize: Size<Double?>
    var contentsSize: Size<Double?>
    var layoutProperties: ResolvedLayoutProperties
}

extension TreeNode where T == ViewProperties {
    
    func layout(
        rootSize: Size<Double>,
        intrinsicSizerBuilder: @escaping (ViewProperties) -> IntrinsicSizer
        ) -> TreeNode<ViewLayout> {

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
        
        let contentSizedTree = measure("   ‣ 📦 Dimensioning Pass", timeScale: .milliseconds) {
            wrapperNode.viewDimensioningPass(
                parentRoughInnerSize: Size(width: rootSize.width, height: rootSize.height),
                parentLayoutType: .block,
                intrinsicSizerBuilder: intrinsicSizerBuilder
            )
        }.result
        
        
        let actualSizedTree = measure("   ‣ 📏 Sizing Pass", timeScale: .milliseconds) {
            contentSizedTree.sizingPass(actualSize: rootSize)
        }.result
        
        let positionedTree = measure("   ‣ 📐 Positioning Pass", timeScale: .milliseconds) {
            actualSizedTree.positioningPass(position: .zero)
        }.result
        
        return positionedTree.children.first!
    }
    
    /**
     Performs the first-pass on the the tree, generating a new tree containing all the view's dimensions we will need to calculate the actual size in the next pass.
     
     - parameter parentRoughInnerSize: The inner-size of the parent, if known.
     - parameter parentLayoutType: The node's parent's layout type (block/abs/flex)
     - parameter intrinsicSizerBuilder: A function that returns a function that returns the intrinsic-size of the view (This is the actual contents (not the children) of the node, eg. text size). This allows for injection of a function that depends on platform-specific implementations.
     */
    func viewDimensioningPass(
        parentRoughInnerSize: Size<Double?>,
        parentLayoutType: LayoutType,
        intrinsicSizerBuilder: @escaping (ViewProperties) -> IntrinsicSizer
        ) -> TreeNode<(properties: ViewProperties, dimensions: ViewDimensions)> {
        
        // make the view's layout properties absolute (in relation to the parent's inner-size)
        let resolvedLayoutProperties = ResolvedLayoutProperties(
            self.value.layout,
            in: parentRoughInnerSize.unwrapped(or: .zero)
        )
        
        // calculate concrete-size (depends on node's layout-type)
        let concreteSize = calculateConcreteSize(
            parentLayoutType: parentLayoutType,
            parentSize: parentRoughInnerSize,
            layoutConcreteSize: resolvedLayoutProperties.size,
            layoutPosition: resolvedLayoutProperties.position,
            layoutMargins: resolvedLayoutProperties.margins,
            flexBasisSize: resolvedLayoutProperties.flexBasisSize
            )
            .clamped(min: resolvedLayoutProperties.minSize, max: resolvedLayoutProperties.maxSize)
        
        // calculate a node's rough-size (combine concrete-size and/or parent's rough-size). No child size used.
        let roughSize = calculateRoughSize(
            parentLayoutType: parentLayoutType,
            parentRoughInnerSize: parentRoughInnerSize,
            concreteSize: concreteSize,
            layoutMargins: resolvedLayoutProperties.margins
            )
            .clamped(min: resolvedLayoutProperties.minSize, max: resolvedLayoutProperties.maxSize)
        
        // when calculating the child-nodes, we need the rough inner-size.
        let roughInnerSize = roughSize.inset(resolvedLayoutProperties.padding)
        
        // calculate the intrinsic-size (eg. the actual contents of the node, like text), constrained to the rough-inner-size.
        // depends on the injected 'intrinsicSizerBuilder', which depends on the node's viewProperties
        let intrinsicSize = intrinsicSizerBuilder(self.value)(roughInnerSize)
        
        // use that rough-size to calculate the contents-sizes (the size of the child based on only its own content) of all the child-nodes. do this by calling "pass-1" recursively on all each child (this could be done in parallel).
        let childNodes = self.children.map {
            $0.viewDimensioningPass(
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
            .clamped(min: resolvedLayoutProperties.minSize.inset(resolvedLayoutProperties.padding),
                     max: resolvedLayoutProperties.maxSize.inset(resolvedLayoutProperties.padding))

        // return the rough-size, concrete-size, intrinsic-size, and contents-size, of the node
        let result = ViewDimensions(
            concreteSize: concreteSize,
            roughSize: roughSize,
            intrinsicSize: intrinsicSize,
            contentsSize: contentsSize,
            layoutProperties: resolvedLayoutProperties
        )
        
        let newNode = TreeNode<(properties: ViewProperties, dimensions: ViewDimensions)>(value: (self.value, result))
        newNode.add(children: childNodes)
        
        return newNode
    }
}

extension TreeNode where T == (properties: ViewProperties, dimensions: ViewDimensions) {
    
    func sizingPass(actualSize: Size<Double>) -> TreeNode<ViewLayout> {
        
        let viewLayout = ViewLayout(
            size: actualSize,
            position: .zero,
            viewProperties: self.value.properties,
            dimensions: self.value.dimensions,
            transform: self.value.properties.layout.transform.absolute(viewSize: actualSize)
        )
        
        let newNode = TreeNode<ViewLayout>(value: viewLayout)
        
        // calculate the actual-size (size taking into account parent's actual-size, sibling's content-sizes, and the node's rough-size/contents-size etc) of all of a node's children. We need the node's actual size to be passed into this function. For the very first node, we can use the screen's size as the actual-size.
        let childNodes: [TreeNode<ViewLayout>] = self.children.map { child in
            
            let childDimensions = child.value.1
            let childViewProperties = child.value.0
            
            let childActualSize = calculateActualSize(
                parentLayoutType: viewLayout.viewProperties.type.layoutType,
                parentSize: actualSize,
                parentPadding: viewLayout.dimensions.layoutProperties.padding,
                parentContentsSize: viewLayout.dimensions.contentsSize,
                dimensions: childDimensions,
                layoutProperties: childViewProperties.layout,
                siblings: child.siblings(excludeSelf: true).map({ $0.value })
                )
                .clamped(min: childDimensions.layoutProperties.minSize, max: childDimensions.layoutProperties.maxSize)
            
            // Once a child's actual-size is known, call "pass-2" recursively on that child using the newly found actual-size. This can be done in parallel.
            return child.sizingPass(actualSize: childActualSize)
        }
        
        newNode.add(children: childNodes)
        
        // return the actual-size
        return newNode
    }
}

extension TreeNode where T == ViewLayout {
    func positioningPass(position: Point<Double>) -> TreeNode<ViewLayout> {
        
        var viewLayout = self.value
        viewLayout.position = position
        
        let newNode = TreeNode<ViewLayout>(value: viewLayout)
        
        // calculate the actual-size (size taking into account parent's actual-size, sibling's content-sizes, and the node's rough-size/contents-size etc) of all of a node's children. We need the node's actual size to be passed into this function. For the very first node, we can use the screen's size as the actual-size.
        let childNodes: [TreeNode<ViewLayout>] = self.children.map { child in
            
            let childViewLayout = child.value
            
            let childViewProperties = childViewLayout.viewProperties
            let childDimensions = childViewLayout.dimensions
            let childSize = childViewLayout.size
            
            let (prevSiblings, nextSiblings) = child.mappedGroupedSiblings({ (size: $0.value.size, dimensions: $0.value.dimensions) })
            
            let childPosition = calculatePosition(
                parentLayoutType: viewLayout.viewProperties.type.layoutType,
                parentSize: viewLayout.size,
                parentPadding: viewLayout.dimensions.layoutProperties.padding,
                parentIntrinsicSize: viewLayout.dimensions.intrinsicSize,
                size: childSize,
                margins: childDimensions.layoutProperties.margins,
                position: childDimensions.layoutProperties.position,
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

// MARK: - Calculate Dimensions

/**
 Calculate the 'concrete' size of a view. This is the size that is defined in the layout properties (size/position). It is excluding margins, but including padding).
 
 - parameter layoutSize: The view's size, as defined in the layout properties.
 - parameter layoutPosition: The view's possible position, as defined in the layout properties. Only used when absolutely positioned.
 - parameter layoutMargins: The view's margins, as defined in the layout properties.
 - parameter parentLayoutType: The view's parent's layout type (block/abs/flex)
 - parameter parentSize: The rough size of the parent (excluding margins, including padding, so not inner or outer-size)
 */
func calculateConcreteSize(parentLayoutType: LayoutType, parentSize: Size<Double?>, layoutConcreteSize: Size<Double?>, layoutPosition: Edges<Double?>, layoutMargins: Edges<Double>, flexBasisSize: Size<Double>?) -> Size<Double?> {
    
    switch parentLayoutType {
    case .block:
        return layoutConcreteSize
    case .flex(let flexProperties):
        
        // if flex then replace the layoutConcreteSize with the flex basis, depending on the flex direction
        var size = layoutConcreteSize
        
        if let flexBasis = flexBasisSize {
            switch flexProperties.direction {
            case .column:
                size.height = flexBasis.height
            case .row:
                size.width = flexBasis.width
            }
        }
        return size
    case .absolute:
        // find the width specified in the layout properties, or nil if no width specified
        let concreteWidth: Double? = {
            // there is a specific width in the layout properties, so use it
            if let w = layoutConcreteSize.width {
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
            if let h = layoutConcreteSize.height {
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
func calculateContentsSize(layoutType: LayoutType, intrinsicSize: Size<Double?>, childDimensions: [ViewDimensions]) -> Size<Double?> {
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

func calculateBlockContentsSize(intrinsicSize: Size<Double?>, childDimensions: [ViewDimensions]) -> Size<Double?> {
    
    // make the height equal to the sum of the height of all the children
    // Block-based views do a weird dance with their inter-element margins,
    // where the `max` of the (n-1) view's marginBottom & current view's marginTop
    // is used as the space between
    let (totalChildrenHeight, _, maxChildWidth) = childDimensions
        .reduce((Double(0), Double(0), Optional<Double>.none)) { res, childDims in
            
            var maxWidth = res.2
            
            let childPaddedContentsSize = childDims.contentsSize.outset(childDims.layoutProperties.padding)
            
            let childPossibleSize = Size(
                width: childDims.concreteSize.width ?? childPaddedContentsSize.width,
                height: childDims.concreteSize.height ?? childPaddedContentsSize.height
            )
            
            // The child has a contentsSize width... use that to calculate the maxWidth
            if let childContentsWidth = childPossibleSize.width {
                maxWidth = max(
                    maxWidth ?? 0,
                    childContentsWidth + childDims.layoutProperties.margins.left + childDims.layoutProperties.margins.right
                )
            }
            
            let smallestSpacing = min(res.1, childDims.layoutProperties.margins.top)
            
            let outerHeight = (childPossibleSize.height ?? 0)
                + childDims.layoutProperties.margins.top + childDims.layoutProperties.margins.bottom
            
            return (
                height: res.0 + outerHeight - smallestSpacing,
                prevMargin: childDims.layoutProperties.margins.bottom,
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


func calculateFlexContentsSize(flexProperties: FlexLayoutProperties, childDimensions: [ViewDimensions]) -> Size<Double?> {

    switch flexProperties.direction {
    case .column:
        // calculate the innersize of the flex view when the subviews are positioned vertically
        
        // get the total height of all the children.
        // also get the maxWidth of all the children (if they are not flexibly sized)
        let (totalChildrenHeight, maxChildWidth) = childDimensions
            .reduce((Double(0), Optional<Double>.none)) { res, childDims in
                
                var maxWidth = res.1
                
                let childPaddedContentsSize = childDims.contentsSize.outset(childDims.layoutProperties.padding)
                
                let childPossibleSize = Size(
                    width: childDims.concreteSize.width ?? childPaddedContentsSize.width,
                    height: childDims.concreteSize.height ?? childPaddedContentsSize.height
                )
                
                // The child has a contentsSize width... use that to calculate the maxWidth
                if let childContentsWidth = childPossibleSize.width {
                    maxWidth = max(
                        maxWidth ?? 0,
                        childContentsWidth + childDims.layoutProperties.margins.left + childDims.layoutProperties.margins.right
                    )
                }
                
                let outerHeight = (childPossibleSize.height ?? 0)
                    + childDims.layoutProperties.margins.top + childDims.layoutProperties.margins.bottom
                
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
                
                let childPaddedContentsSize = childDims.contentsSize.outset(childDims.layoutProperties.padding)
                
                let childPossibleSize = Size(
                    width: childDims.concreteSize.width ?? childPaddedContentsSize.width,
                    height: childDims.concreteSize.height ?? childPaddedContentsSize.height
                )
                
                // The child has a contentsSize height... use that to calculate the maxHeight
                if let childContentsHeight = childPossibleSize.height {
                    maxHeight = max(
                        maxHeight ?? 0,
                        childContentsHeight + childDims.layoutProperties.margins.top + childDims.layoutProperties.margins.bottom
                    )
                }
                
                let outerWidth = (childPossibleSize.width ?? 0)
                    + childDims.layoutProperties.margins.left + childDims.layoutProperties.margins.right
                
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

// MARK: - Calculate Actual Sizes

/**
 Calculate the 'actual' size of a view. This is the final size of the view, given the size of all the children etc.
 */
func calculateActualSize(parentLayoutType: LayoutType, parentSize: Size<Double>, parentPadding: Edges<Double>, parentContentsSize: Size<Double?>, dimensions: ViewDimensions, layoutProperties: LayoutProperties, siblings: [(ViewProperties, ViewDimensions)]) -> Size<Double> {
    switch parentLayoutType {
    case .block:
        return calculateBlockChildActualSize(
            parentSize: parentSize,
            parentPadding: parentPadding,
            concreteSize: dimensions.concreteSize,
            contentsSize: dimensions.contentsSize,
            padding: dimensions.layoutProperties.padding,
            margins: dimensions.layoutProperties.margins
        )
    case .absolute:
        return calculateAbsoluteChildActualSize(
            concreteSize: dimensions.concreteSize,
            contentsSize: dimensions.contentsSize,
            padding: dimensions.layoutProperties.padding
        )
    case .flex(let flexProperties):
        return calculateFlexChildActualSize(
            flexProperties: flexProperties,
            concreteSize: dimensions.concreteSize,
            contentsSize: dimensions.contentsSize,
            padding: dimensions.layoutProperties.padding,
            margins: dimensions.layoutProperties.margins,
            flexGrow: layoutProperties.flexGrow,
            flexShrink: layoutProperties.flexShrink,
            siblings: siblings,
            parentSize: parentSize,
            parentPadding: parentPadding,
            parentContentsSize: parentContentsSize
        )
    }
}

func calculateBlockChildActualSize(parentSize: Size<Double>, parentPadding: Edges<Double>, concreteSize: Size<Double?>, contentsSize: Size<Double?>, padding: Edges<Double>, margins: Edges<Double>) -> Size<Double> {
    
    let paddedContentsSize = contentsSize.unwrapped(or: .zero).outset(padding)
    let parentInnerSize = parentSize.inset(parentPadding).inset(margins)
    
    return Size(
        width: concreteSize.width ?? parentInnerSize.width,
        height: concreteSize.height ?? paddedContentsSize.height
    )
}

func calculateAbsoluteChildActualSize(concreteSize: Size<Double?>, contentsSize: Size<Double?>, padding: Edges<Double>) -> Size<Double> {
    
    let paddedContentsSize = contentsSize.unwrapped(or: .zero).outset(padding)
    
    return Size(
        width: concreteSize.width ?? paddedContentsSize.width,
        height: concreteSize.height ?? paddedContentsSize.height
    )
}

func calculateFlexChildActualSize(flexProperties: FlexLayoutProperties, concreteSize: Size<Double?>, contentsSize: Size<Double?>, padding: Edges<Double>, margins: Edges<Double>, flexGrow: Double, flexShrink: Double, siblings: [(ViewProperties, ViewDimensions)], parentSize: Size<Double>, parentPadding: Edges<Double>, parentContentsSize: Size<Double?>) -> Size<Double> {
    
    let paddedContentsSize = contentsSize.unwrapped(or: .zero).outset(padding)
    let actualSize = concreteSize.unwrapped(or: paddedContentsSize)

    // flex-shrink is actually handled slightly differently than flex-grow.
    // flex-shrink is normalized relative to a scaled version.
    // so, for views with `size@shrink/grow` values of `[50px@1, 100px@0, 100px@3]`, to calculate the normalized version of the first view's shrink or grow we do the following:
    // flex-grow:   `1/(1+0+3) = 0.25`
    // flex-shrink: `(1*50) / (1*50 + 0*100 + 3*100) = 0.1429`
    let scaledShrink = actualSize.multipling(by: flexShrink)
    let (totalGrow, totalScaledShrink) = siblings.reduce((flexGrow, scaledShrink)) {
        let siblingPaddedContentsSize = $1.1.contentsSize.unwrapped(or: .zero).outset($1.1.layoutProperties.padding)
        let siblingActualSize = $1.1.concreteSize.unwrapped(or: siblingPaddedContentsSize)
        
        return (
            $0.0 + $1.0.layout.flexGrow,
            $0.1.adding(siblingActualSize.multipling(by: $1.0.layout.flexShrink))
        )
    }
    
    let normalizedGrow: Double = totalGrow != 0 ? flexGrow / totalGrow : 0
    let normalizedShrinkSize: Size<Double> = scaledShrink.dividing(by: totalScaledShrink)
    
    // we now have viewDimensions that are based on the view's contents/intrinsic size etc
    // now we need to apply the flex-layout to those dimensions    
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
                return paddedContentsSize.width
            }
        }()
        
        let height: Double = {
            let freeSpace = parentSize.height - parentPadding.top - parentPadding.bottom - (parentContentsSize.height ?? 0)
            
            // we then need to either size that down or up, depending on flex-grow/shrink
            if freeSpace > 0 {
                return actualSize.height + (freeSpace * normalizedGrow)
            } else {
                return actualSize.height + (freeSpace * normalizedShrinkSize.height)
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
                return paddedContentsSize.height
            }
        }()
        
        let width: Double = {
            let freeSpace = parentSize.width - parentPadding.left - parentPadding.right - (parentContentsSize.width ?? 0)
            
            // we then need to either size that down or up, depending on flex-grow/shrink
            if freeSpace > 0 {
                return actualSize.width + (freeSpace * normalizedGrow)
            } else {
                return actualSize.width + (freeSpace * normalizedShrinkSize.width)
            }
        }()
        
        return Size(
            width: width,
            height: height
        )
    }
}

// MARK: - Calculate Position

func calculatePosition(parentLayoutType: LayoutType, parentSize: Size<Double>, parentPadding: Edges<Double>, parentIntrinsicSize: Size<Double?>, size: Size<Double>, margins: Edges<Double>, position: Edges<Double?>, layoutProperties: LayoutProperties, prevSiblings: [(size: Size<Double>, dimensions: ViewDimensions)], nextSiblings: [(size: Size<Double>, dimensions: ViewDimensions)]) -> Point<Double> {
    // TODO: different default gravity if system is right-to-left layout
    let gravity = layoutProperties.gravity ?? .left
    
    switch parentLayoutType {
    case .block:
        return calculateBlockChildPosition(
            parentSize: parentSize,
            parentPadding: parentPadding,
            parentIntrinsicSize: parentIntrinsicSize,
            size: size,
            margins: margins,
            gravity: gravity,
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

func calculateBlockChildPosition(parentSize: Size<Double>, parentPadding: Edges<Double>, parentIntrinsicSize: Size<Double?>, size: Size<Double>, margins: Edges<Double>, gravity: HorizontalGravity, prevSiblings: [(size: Size<Double>, dimensions: ViewDimensions)]) -> Point<Double> {
    
    let originY: Double = {
        
        let (totalPrevSiblingHeight, prevBottomMargin) = prevSiblings.reduce((Double(0), Double(0))) { res, prevSibling in
            let margins = prevSibling.dimensions.layoutProperties.margins
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
        switch gravity {
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

func calculateFlexChildPosition(flexProperties: FlexLayoutProperties, parentSize: Size<Double>, parentPadding: Edges<Double>, prevSiblings: [(size: Size<Double>, dimensions: ViewDimensions)], nextSiblings: [(size: Size<Double>, dimensions: ViewDimensions)], size: Size<Double>, margins: Edges<Double>) -> Point<Double> {
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
    prevSiblings: [(size: Size<Double>, dimensions: ViewDimensions)],
    nextSiblings: [(size: Size<Double>, dimensions: ViewDimensions)],
    size: Size<Double>,
    margins: Edges<Double>
    ) -> Point<Double> {
    
    let parentInnerSize = parentSize.inset(parentPadding)
    let outerSize = size.outset(margins)
    
    // the width of all the preceding views
    let totalPrevSiblingWidth = prevSiblings.reduce(0, {
        $0 + $1.size.outset($1.dimensions.layoutProperties.margins).width
    })
    // the width of all the following views
    let totalTrailingWidth = nextSiblings.reduce(0, {
        $0 + $1.size.outset($1.dimensions.layoutProperties.margins).width
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
    prevSiblings: [(size: Size<Double>, dimensions: ViewDimensions)],
    nextSiblings: [(size: Size<Double>, dimensions: ViewDimensions)],
    size: Size<Double>,
    margins: Edges<Double>
    ) -> Point<Double> {
    
    let parentInnerSize = parentSize.inset(parentPadding)
    let outerSize = size.outset(margins)
    
    // the height of all the preceding views
    let totalPrevSiblingHeight = prevSiblings.reduce(0, {
        $0 + $1.size.outset($1.dimensions.layoutProperties.margins).height
    })
    // the height of all the following views
    let totalTrailingHeight = nextSiblings.reduce(0, {
        $0 + $1.size.outset($1.dimensions.layoutProperties.margins).height
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
