//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

extension TreeNode where T == (properties: ViewProperties, dimensions: ViewDimensions) {
    
    /**
     This will convert a tree of `ViewProperties`/`ViewDimensions` pairs into a tree of `ViewLayout`s (with no position).
     
     First it calculates the final size of the current node using the provided `parentSize`. It then creates a new `TreeNode<ViewLayout>` using this size.
     
     Finally, it recursively calls this function for each child, adding the returned sized-child node as a child of the node created earlier.
     
     - parameter parentSize: This is the size into which we placing the current node - for the root node this would be the size of the screen.
     */
    func sizingPass(parentSize: Size<Double>) -> TreeNode<ViewLayout> {
        
        let parent = self.parent?.value
        
        let parentLayoutType = parent?.properties.type.layoutType ?? .block
        let parentPadding = parent?.dimensions.layoutProperties.padding ?? .zero
        let parentContentSize = parent?.dimensions.contentsSize ?? Size.init(nil)
        
        var dimensions = self.value.dimensions
        
        // recalculate the view's absolute layout properties
        let resolvedLayoutProperties = resolveLayoutProperties(
            self.value.properties.layout,
            parentSize: parentSize.optional,
            parentPadding: parentPadding,
            parentLayoutType: parentLayoutType
        )
        
        // check if anything has changed (because it was relative to a different parent size.
        if self.value.dimensions.layoutProperties != resolvedLayoutProperties {
            
            // if there was a change in the layout properties, we might need to recalculate all the dimensions
            dimensions.layoutProperties = resolvedLayoutProperties
            
            dimensions.concreteSize = calculateConcreteSize(
                parentLayoutType: parentLayoutType,
                parentSize: parentSize.optional,
                layoutConcreteSize: resolvedLayoutProperties.concreteSize,
                layoutPosition: resolvedLayoutProperties.position,
                layoutMargins: resolvedLayoutProperties.margins,
                flexBasisSize: resolvedLayoutProperties.flexBasisSize
                )
                .clamped(min: resolvedLayoutProperties.minSize, max: resolvedLayoutProperties.maxSize)

            // for some reason web renderers only re-calculate the width, not the height.
            dimensions.relativeSize = calculateConcreteSize(
                parentLayoutType: parentLayoutType,
                parentSize: parentSize.optional,
                layoutConcreteSize: resolvedLayoutProperties.relativeSize,
                layoutPosition: resolvedLayoutProperties.position,
                layoutMargins: resolvedLayoutProperties.margins,
                flexBasisSize: resolvedLayoutProperties.flexBasisSize
                )
                .clamped(min: resolvedLayoutProperties.minSize, max: resolvedLayoutProperties.maxSize)
            
            // TODO: maybe need to recalculate the contents size? only if no concrete size? too intensive?
        }
        
        // calculate the final size of the current node
        let actualSize = calculateActualSize(
            parentLayoutType: parentLayoutType,
            parentSize: parentSize,
            parentPadding: parentPadding,
            parentContentsSize: parentContentSize,
            dimensions: dimensions,
            layoutProperties: self.value.properties.layout,
            siblings: self.siblings(excludeSelf: true).map({ $0.value })
            )
            .clamped(
                min: dimensions.layoutProperties.minSize,
                max: dimensions.layoutProperties.maxSize
        )
        
        let viewLayout = ViewLayout(
            size: actualSize,
            position: .zero,
            viewProperties: self.value.properties,
            dimensions: dimensions,
            transform: self.value.properties.layout.transform.absolute(viewSize: actualSize)
        )
        
        let newNode = TreeNode<ViewLayout>(value: viewLayout)
        for child in self.children {
            newNode.add(child: child.sizingPass(parentSize: actualSize))
        }
        
        return newNode
    }
}

// MARK: - Actual Sizes Calculators

/**
 Calculate the 'actual' size of a view. This is the final size of the view, given the size of all the children etc.
 */
private func calculateActualSize(
    parentLayoutType: LayoutType,
    parentSize: Size<Double>,
    parentPadding: Edges<Double>,
    parentContentsSize: Size<Double?>,
    dimensions: ViewDimensions,
    layoutProperties: LayoutProperties,
    siblings: [(ViewProperties, ViewDimensions)]
    ) -> Size<Double> {
    
    switch parentLayoutType {
    case .block:
        return calculateBlockChildActualSize(
            parentSize: parentSize,
            parentPadding: parentPadding,
            concreteSize: dimensions.concreteSize,
            relativeSize: dimensions.relativeSize,
            contentsSize: dimensions.contentsSize,
            padding: dimensions.layoutProperties.padding,
            margins: dimensions.layoutProperties.margins,
            wrapsContent: dimensions.layoutProperties.wrapsContent
        )
    case .absolute:
        return calculateAbsoluteChildActualSize(
            concreteSize: dimensions.concreteSize,
            relativeSize: dimensions.relativeSize,
            contentsSize: dimensions.contentsSize,
            padding: dimensions.layoutProperties.padding
        )
    case .flex(let flexProperties):
        return calculateFlexChildActualSize(
            parentSize: parentSize,
            parentPadding: parentPadding,
            parentContentsSize: parentContentsSize,
            flexProperties: flexProperties,
            concreteSize: dimensions.concreteSize,
            relativeSize: dimensions.relativeSize,
            contentsSize: dimensions.contentsSize,
            padding: dimensions.layoutProperties.padding,
            margins: dimensions.layoutProperties.margins,
            flexGrow: layoutProperties.flexGrow,
            flexShrink: layoutProperties.flexShrink,
            siblings: siblings
        )
    }
}

/**
 Generates the final size of a block-layout view's childView.
 */
private func calculateBlockChildActualSize(
    parentSize: Size<Double>,
    parentPadding: Edges<Double>,
    concreteSize: Size<Double?>,
    relativeSize: Size<Double?>,
    contentsSize: Size<Double?>,
    padding: Edges<Double>,
    margins: Edges<Double>,
    wrapsContent: Size<Bool>
    ) -> Size<Double> {
    
    let paddedContentsSize = contentsSize.unwrapped(or: .zero).outset(padding)
    let parentInnerSize = parentSize.inset(parentPadding).inset(margins)
    
    return Size(
        width: concreteSize.width ?? relativeSize.width ?? (wrapsContent.width ? paddedContentsSize.width : parentInnerSize.width),
        height: concreteSize.height ?? relativeSize.height ?? paddedContentsSize.height
    )
}

/**
 Generates the final size of an AbsoluteLayout childView.
 */
private func calculateAbsoluteChildActualSize(
    concreteSize: Size<Double?>,
    relativeSize: Size<Double?>,
    contentsSize: Size<Double?>,
    padding: Edges<Double>
    ) -> Size<Double> {
    
    let paddedContentsSize = contentsSize.unwrapped(or: .zero).outset(padding)
    
    return Size(
        width: concreteSize.width ?? relativeSize.width ?? paddedContentsSize.width,
        height: concreteSize.height ?? relativeSize.height ?? paddedContentsSize.height
    )
}

/**
 Generates the final size of a FlexLayout childView.
 */
private func calculateFlexChildActualSize(
    parentSize: Size<Double>,
    parentPadding: Edges<Double>,
    parentContentsSize: Size<Double?>,
    flexProperties: FlexLayoutProperties,
    concreteSize: Size<Double?>,
    relativeSize: Size<Double?>,
    contentsSize: Size<Double?>,
    padding: Edges<Double>,
    margins: Edges<Double>,
    flexGrow: Double,
    flexShrink: Double,
    siblings: [(ViewProperties, ViewDimensions)]
    ) -> Size<Double> {
    
    let paddedContentsSize = contentsSize.unwrapped(or: .zero).outset(padding)
    let actualSize = concreteSize
        .unwrapped(or: relativeSize)
        .unwrapped(or: paddedContentsSize)
    
    // flex-shrink is actually handled slightly differently than flex-grow.
    // flex-shrink is normalized relative to a scaled version.
    // so, for views with `size@shrink/grow` values of `[50px@1, 100px@0, 100px@3]`, to calculate the normalized version of the first view's shrink or grow we do the following:
    // flex-grow:   `1/(1+0+3) = 0.25`
    // flex-shrink: `(1*50) / (1*50 + 0*100 + 3*100) = 0.1429`
    let scaledShrink = actualSize.multipling(by: flexShrink)
    let (totalGrow, totalScaledShrink) = siblings.reduce((flexGrow, scaledShrink)) {
        let siblingPaddedContentsSize = $1.1.contentsSize.unwrapped(or: .zero).outset($1.1.layoutProperties.padding)
        let siblingActualSize = $1.1.concreteSize
            .unwrapped(or: $1.1.relativeSize)
            .unwrapped(or: siblingPaddedContentsSize)
        
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
            } else if let relativeWidth = relativeSize.width {
                return relativeWidth
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
            } else if let relativeHeight = relativeSize.height {
                return relativeHeight
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
