//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

extension TreeNode where T == ViewLayout {
    
    /**
     This will convert a tree of `ViewLayout`s that dont have positions into a tree of ViewLayouts that have valid position values.
     
     First it calculates the position of the current node. It then creates a new `TreeNode<ViewLayout>` using this position.

     Finally, it recursively calls this function for each child, adding the returned positioned-child node as a child of the node created earlier.
     */
    func positioningPass(systemGravity: HorizontalGravity) -> TreeNode<ViewLayout> {
        
        var viewLayout = self.value
        
        let parent = self.parent?.value
        
        let parentLayoutType = parent?.viewProperties.type.layoutType ?? .block
        let parentSize = parent?.size ?? .zero
        let parentPadding = parent?.dimensions.layoutProperties.padding ?? .zero
        let parentIntrinsicSize = parent?.dimensions.intrinsicSize ?? .init(nil)
        
        let (prevSiblings, nextSiblings) = self.mappedGroupedSiblings({ (size: $0.value.size, dimensions: $0.value.dimensions) })
        
        // calculate the position of the current node
        let position = calculatePosition(
            parentLayoutType: parentLayoutType,
            parentSize: parentSize,
            parentPadding: parentPadding,
            parentIntrinsicSize: parentIntrinsicSize,
            
            size: viewLayout.size,
            margins: viewLayout.dimensions.layoutProperties.margins,
            position: viewLayout.dimensions.layoutProperties.position,
            layoutProperties: viewLayout.viewProperties.layout,
            prevSiblings: prevSiblings,
            nextSiblings: nextSiblings,
            systemGravity: systemGravity
        )
        
        viewLayout.position = position
        
        let newNode = TreeNode<ViewLayout>(value: viewLayout)
        for child in self.children {
            newNode.add(child: child.positioningPass(systemGravity: systemGravity))
        }
        return newNode
    }
}

// MARK: - Position Calculators

/**
 Generates the location of view. This position is local, so within the parentView coordinate space.
 */
private func calculatePosition(
    parentLayoutType: LayoutType,
    parentSize: Size<Double>,
    parentPadding: Edges<Double>,
    parentIntrinsicSize: Size<Double?>,
    size: Size<Double>,
    margins: Edges<Double>,
    position: Edges<Double?>,
    layoutProperties: LayoutProperties,
    prevSiblings: [(size: Size<Double>, dimensions: ViewDimensions)],
    nextSiblings: [(size: Size<Double>, dimensions: ViewDimensions)],
    systemGravity: HorizontalGravity
    ) -> Point<Double> {
    
    switch parentLayoutType {
    case .block:
        return calculateBlockChildPosition(
            parentSize: parentSize,
            parentPadding: parentPadding,
            parentIntrinsicSize: parentIntrinsicSize,
            size: size,
            margins: margins,
            gravity: layoutProperties.gravity ?? systemGravity,
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
            margins: margins,
            gravity: layoutProperties.gravity
        )
    }
}

/**
 Generates the location of a block-layout view's child view.
 */
private func calculateBlockChildPosition(
    parentSize: Size<Double>,
    parentPadding: Edges<Double>,
    parentIntrinsicSize: Size<Double?>,
    size: Size<Double>,
    margins: Edges<Double>,
    gravity: HorizontalGravity,
    prevSiblings: [(size: Size<Double>, dimensions: ViewDimensions)]
    ) -> Point<Double> {
    
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

/**
 Generates the location of an AbsoluteLayout child view.
 */
private func calculateAbsoluteChildPosition(
    size: Size<Double>,
    position: Edges<Double?>,
    margins: Edges<Double>,
    parentSize: Size<Double>,
    parentPadding: Edges<Double>
    ) -> Point<Double> {
    
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

/**
 Generates the location of a FlexLayout child view.
 */
private func calculateFlexChildPosition(
    flexProperties: FlexLayoutProperties,
    parentSize: Size<Double>,
    parentPadding: Edges<Double>,
    prevSiblings: [(size: Size<Double>, dimensions: ViewDimensions)],
    nextSiblings: [(size: Size<Double>, dimensions: ViewDimensions)],
    size: Size<Double>,
    margins: Edges<Double>,
    gravity: HorizontalGravity?
    ) -> Point<Double> {
    
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
            margins: margins,
            gravity: gravity
        )
    }
}

/**
 Generates the location of a FlexLayout child view when it is in a row.
 */
private func calculateFlexChildRowPosition(
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
private func calculateFlexChildColumnPosition(
    justification: FlexLayoutProperties.ContentJustification,
    itemAlignment: FlexLayoutProperties.ItemAlignment,
    parentSize: Size<Double>,
    parentPadding: Edges<Double>,
    prevSiblings: [(size: Size<Double>, dimensions: ViewDimensions)],
    nextSiblings: [(size: Size<Double>, dimensions: ViewDimensions)],
    size: Size<Double>,
    margins: Edges<Double>,
    gravity: HorizontalGravity?
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
        // when aligning horizontally, gravity trumps the flex itemAlignment property
        switch gravity {
        case .left?:
            return parentPadding.left + margins.left
        case .right?:
            return parentSize.width - parentPadding.right - margins.right - size.width
        case .center?:
            
            let parentInnerWidth = parentSize.width - parentPadding.left - parentPadding.right
            let outerWidth = size.width + margins.left + margins.right
            
            return parentPadding.left + (parentInnerWidth / 2) - (outerWidth / 2) + margins.left
        case nil:
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
        }
    }()
    
    return Point(
        x: originX,
        y: originY
    )
}
