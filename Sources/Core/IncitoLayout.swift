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

extension TreeNode where T == ViewProperties {
    
    func layout(
        rootSize: Size<Double>,
        intrinsicSizerBuilder: @escaping (ViewProperties) -> IntrinsicSizer
        ) -> TreeNode<ViewLayout> {

        var wrapperLayout = LayoutProperties.empty
        wrapperLayout.size.width = .unit(.pts(rootSize.width))
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
                parentRoughSize: rootSize.optional,
                parentPadding: .zero,
                parentLayoutType: .block,
                intrinsicSizerBuilder: intrinsicSizerBuilder
            )
        }.result
        
        let actualSizedTree = measure("   ‣ 📏 Sizing Pass", timeScale: .milliseconds) {
            contentSizedTree.sizingPass(parentSize: rootSize)
        }.result
        
        let positionedTree = measure("   ‣ 📐 Positioning Pass", timeScale: .milliseconds) {
            actualSizedTree.positioningPass()
        }.result
        
        return positionedTree.children.first!
    }
}

// MARK: - Layout-specific Types

/**
 The result of performing the layout pass.
 */
struct ViewLayout {
    var size: Size<Double>
    var position: Point<Double>
    var viewProperties: ViewProperties
    var dimensions: ViewDimensions
    var transform: Transform<Double>
}

typealias IntrinsicSizer = (_ sizeConstraint: Size<Double?>) -> Size<Double?>

/// The different ways of sizing/positioning views. Every ViewType will layout it's children using one of the following layout modes.
enum LayoutType {
    case absolute
    case block
    case flex(FlexLayoutProperties)
}

extension ViewType {
    /// How the children of this view will be laid out
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

/**
 These are the absolute versions of the LayoutProperties. Some of the `LayoutProperties` values can be percentages of their parent's size. This resolves that relativity, making the values absolute.
 */
struct ResolvedLayoutProperties: Equatable {
    var position: Edges<Double?>
    var margins: Edges<Double>
    var padding: Edges<Double>
    
    var maxSize: Size<Double>
    var minSize: Size<Double>
    
    var size: Size<Double?> // nil if fitting to child
    
    var flexBasisSize: Size<Double>? // nil if auto
    
    /// parentSize is the container's inner size (size - padding)
    init(_ properties: LayoutProperties, in parentSize: Size<Double>) {
        self.maxSize = Size(
            width: properties.maxSize.width?.absolute(in: parentSize.width) ?? .infinity,
            height: properties.maxSize.height?.absolute(in: parentSize.height) ?? .infinity
        )
        self.minSize = Size(
            width: properties.minSize.width?.absolute(in: parentSize.width) ?? 0,
            height: properties.minSize.height?.absolute(in: parentSize.height) ?? 0
        )
        self.size = Size(
            width: properties.size.width?.absolute(in: parentSize.width),
            height: properties.size.height?.absolute(in: parentSize.height)
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
