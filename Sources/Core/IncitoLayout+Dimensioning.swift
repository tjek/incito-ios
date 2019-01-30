//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

extension TreeNode where T == ViewProperties {
    
    /**
     Performs the first-pass on the the tree, generating a new tree containing all the view's dimensions, which we will need to calculate the actual size in the next pass.
     
     - parameter parentRoughInnerSize: The inner-size of the parent, if known.
     - parameter parentLayoutType: The node's parent's layout type (block/abs/flex)
     - parameter intrinsicSizerBuilder: A function that returns a function that returns the intrinsic-size of the view (This is the actual contents (not the children) of the node, eg. text size). This allows for injection of a function that depends on platform-specific implementations.
     */
    func viewDimensioningPass(
        parentRoughSize: Size<Double?>,
        parentPadding: Edges<Double> = .zero,
        parentLayoutType: LayoutType,
        intrinsicSizerBuilder: @escaping (ViewProperties) -> IntrinsicSizer
        ) -> TreeNode<(properties: ViewProperties, dimensions: ViewDimensions)> {
        
        let parentRoughInnerSize = parentRoughSize.inset(parentPadding)
        
        // make the view's layout properties absolute
        let resolvedLayoutProperties = resolveLayoutProperties(
            self.value.layout,
            parentSize: parentRoughSize,
            parentPadding: parentPadding,
            parentLayoutType: parentLayoutType
        )
        
        // calculate concrete-size (depends on node's layout-type)
        let concreteSize = calculateConcreteSize(
            parentLayoutType: parentLayoutType,
            parentSize: parentRoughSize,
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
                parentRoughSize: roughSize,
                parentPadding: resolvedLayoutProperties.padding,
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



// MARK: - Dimensions Calculators

/**
 Converts the possibly %-based layoutProperties into concrete layout properties, relative to the parent's size.
 Depending on the layout-type of the parent, it is relative to either the inner or main size of the parent.
 */
func resolveLayoutProperties(
    _ layoutProperties: LayoutProperties,
    parentSize: Size<Double?>,
    parentPadding: Edges<Double>,
    parentLayoutType: LayoutType
    ) -> ResolvedLayoutProperties {
    
    let relativeToSize: Size<Double?>
    
    switch parentLayoutType {
    case .absolute:
        relativeToSize = parentSize
    case .block,
         .flex:
        relativeToSize = parentSize.inset(parentPadding)
    }
    
    return ResolvedLayoutProperties(
        layoutProperties,
        in: relativeToSize.unwrapped(or: .zero).clamped(min: .zero, max: Size(Double.infinity))
    )
}

/**
 Calculate the 'concrete' size of a view. This is the size that is defined in the layout properties (size/position). It is excluding margins, but including padding). If the view has a flex-basis, and is the child of a flexlayout, then the flex-basis overrides any layout property sizes.
 
 - parameter parentLayoutType: The view's parent's layout type (block/abs/flex)
 - parameter parentSize: The rough size of the parent (excluding margins, including padding, so not inner or outer-size)
 - parameter layoutConcreteSize: The view's size, as defined in the layout properties.
 - parameter layoutPosition: The view's possible position, as defined in the layout properties. Only used when absolutely positioned.
 - parameter layoutMargins: The view's margins, as defined in the layout properties.
 - parameter flexBasisSize: The flex basis of the view. It is a size as if it was a % it may be different in different directions depending on the size of the parent.
 */
func calculateConcreteSize(
    parentLayoutType: LayoutType,
    parentSize: Size<Double?>,
    layoutConcreteSize: Size<Double?>,
    layoutPosition: Edges<Double?>,
    layoutMargins: Edges<Double>,
    flexBasisSize: Size<Double>?
    ) -> Size<Double?> {
    
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

// MARK: - Rough Size

/**
 Calculate the 'rough' size of a view. This is how big we think a view is, only taking into account the parent's size, not any of the children's sizes. Basically, this is the constraint used for calculating the content size.
 
 - parameter parentLayoutType: The view's parent's layout type (block/abs/flex)
 - parameter parentRoughInnerSize: The rough-size of the parent, minus the parent's padding.
 - parameter concreteSize: The size of the view as defined solely by the layout properties.
 - parameter margins: The margins of the view.
 */
private func calculateRoughSize(
    parentLayoutType: LayoutType,
    parentRoughInnerSize: Size<Double?>,
    concreteSize: Size<Double?>,
    layoutMargins: Edges<Double>
    ) -> Size<Double?> {
    
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

// MARK: - Contents Size

/**
 Calculate the 'contents' size of a view. This is based on the sizes of all the child-nodes. This is the 'inner-size' of the view, if any of it's children influence it's size.
 */
private func calculateContentsSize(
    layoutType: LayoutType,
    intrinsicSize: Size<Double?>,
    childDimensions: [ViewDimensions]
    ) -> Size<Double?> {
    
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
            flexDirection: flexProperties.direction,
            childDimensions: childDimensions
        )
    }
}

/**
 Generates an optional width/height for a block-layout's contents.
 */
private func calculateBlockContentsSize(
    intrinsicSize: Size<Double?>,
    childDimensions: [ViewDimensions]
    ) -> Size<Double?> {
    
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


/**
 Generates an optional width/height for a FlexLayout's contents. This depends on the type of flex-layout we
 */
private func calculateFlexContentsSize(
    flexDirection: FlexLayoutProperties.Direction,
    childDimensions: [ViewDimensions]
    ) -> Size<Double?> {
    
    switch flexDirection {
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
