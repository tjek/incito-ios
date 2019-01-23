//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

extension Comparable {
    func clamped(min: Self, max: Self) -> Self {
        return Swift.min(Swift.max(self, min), max)
    }
}

////////////////////////////
// MARK: - Point
////////////////////////////

struct Point<Value> {
    var x, y: Value
}
typealias PointDbl = Point<Double>

extension Point: Equatable where Value: Equatable {
    static func == (lhs: Point<Value>, rhs: Point<Value>) -> Bool {
        return lhs.x == rhs.x
            && lhs.y == rhs.y
    }
}

extension Point where Value: Numeric {
    static var zero: Point {
        return Point(x: 0, y: 0)
    }
}

extension Point: CustomDebugStringConvertible {
    var debugDescription: String {
        return "{ x:\(x), y:\(y) }"
    }
}

////////////////////////////
// MARK: - Size
////////////////////////////

struct Size<Value> {
    var width, height: Value
}
typealias SizeDbl = Size<Double>

extension Size: Equatable where Value: Equatable {
    static func == (lhs: Size<Value>, rhs: Size<Value>) -> Bool {
        return lhs.width == rhs.width
            && lhs.height == rhs.height
    }
}

extension Size where Value: Numeric {
    static var zero: Size {
        return Size(width: 0, height: 0)
    }
}

// MARK: Inset

extension Size where Value: Numeric {
    func inset(_ edges: Edges<Value>) -> Size {
        return Size(width: self.width - edges.left - edges.right,
                    height: self.height - edges.top - edges.bottom)
    }
    func outset(_ edges: Edges<Value>) -> Size {
        return inset(edges.negated)
    }
}

// TODO: Would like to do this on Optional<Numeric>, but no clear way of doing that.
extension Size where Value == Double? {
    func inset(_ edges: Edges<Double>) -> Size {
        var insetSize = self
        if let w = insetSize.width {
            insetSize.width = w - edges.left - edges.right
        }
        if let h = insetSize.height {
            insetSize.height = h - edges.top - edges.bottom
        }
        return insetSize
    }
    func outset(_ edges: Edges<Double>) -> Size {
        return inset(edges.negated)
    }
}

// MARK: Clamped

extension Size where Value: Comparable {
    func clamped(min: Size<Value>, max: Size<Value>) -> Size {
        return Size(
            width: self.width.clamped(min: min.width, max: max.width),
            height: self.height.clamped(min: min.height, max: max.height)
        )
    }
}

// TODO: Would like to do this on Optional<Comparable>, but no clear way of doing that.
extension Size where Value == Double? {
    func clamped(min: Size<Double>, max: Size<Double>) -> Size<Double?> {
        var clampedSize = self
        if let w = clampedSize.width {
            clampedSize.width = w.clamped(min: min.width, max: max.width)
        }
        if let h = clampedSize.height {
            clampedSize.height = h.clamped(min: min.height, max: max.height)
        }
        return clampedSize
    }
}

extension Size where Value == Double? {
    /// Use the width or height if not nil, otherwise fallback to the provided size's dimensions.
    func unwrapped(or fallbackSize: Size<Double>) -> Size<Double> {
        return Size<Double>(
            width: self.width ?? fallbackSize.width,
            height: self.height ?? fallbackSize.height
        )
    }
}

extension Size: CustomDebugStringConvertible {
    var debugDescription: String {
        return "{ w:\(width), h:\(height) }"
    }
}

////////////////////////////
// MARK: - Rect
////////////////////////////

struct Rect<Value> {
    var origin: Point<Value>
    var size: Size<Value>
}
typealias RectDbl = Rect<Double>

extension Rect: Equatable where Value: Equatable {
    static func == (lhs: Rect<Value>, rhs: Rect<Value>) -> Bool {
        return lhs.origin == rhs.origin
            && lhs.size == rhs.size
    }
}

extension Rect where Value: Numeric {
    static var zero: Rect {
        return Rect(origin: .zero, size: .zero)
    }
}

extension Rect: CustomDebugStringConvertible {
    var debugDescription: String {
        return "{ x:\(origin.x), y:\(origin.y), w:\(size.width), h:\(size.height) }"
    }
}

////////////////////////////
// MARK: - Edges
////////////////////////////

struct Edges<Value> {
    var top, left, bottom, right: Value
}

extension Edges {
    init(_ val: Value) {
        self.init(top: val, left: val, bottom: val, right: val)
    }
}

extension Edges: Equatable where Value: Equatable {
    static func == (lhs: Edges<Value>, rhs: Edges<Value>) -> Bool {
        return lhs.top == rhs.top
            && lhs.left == rhs.left
            && lhs.bottom == rhs.bottom
            && lhs.right == rhs.right
    }
    
    /// If all edge values are the same.
    var isUniform: Bool {
        return self.top == self.right
            && self.right == self.bottom
            && self.bottom == self.left
    }
}

extension Edges where Value: Numeric {
    static var zero: Edges {
        return Edges(top: 0, left: 0, bottom: 0, right: 0)
    }
}

extension Edges where Value: Numeric {
    var negated: Edges {
        return Edges(top: self.top * -1, left: self.left * -1, bottom: self.bottom * -1, right: self.right * -1)
    }
}

extension Edges: CustomDebugStringConvertible where Value: Equatable {
    var debugDescription: String {
        if isUniform {
            return "{ \(top) }"
        } else {
            return "{ t: \(top), l: \(left), b: \(bottom), r: \(right) }"
        }
    }
}

////////////////////////////
// MARK: - Corners
////////////////////////////

struct Corners<Value> {
    var topLeft, topRight, bottomLeft, bottomRight: Value
}

extension Corners {
    init(_ val: Value) {
        self.init(topLeft: val, topRight: val, bottomLeft: val, bottomRight: val)
    }
}

extension Corners: Equatable where Value: Equatable {
    static func == (lhs: Corners<Value>, rhs: Corners<Value>) -> Bool {
        return lhs.topLeft == rhs.topLeft
            && lhs.topRight == rhs.topRight
            && lhs.bottomLeft == rhs.bottomLeft
            && lhs.bottomRight == rhs.bottomRight
    }
    
    /// If all corner values are the same.
    var isUniform: Bool {
        return self.topLeft == self.topRight
            && self.topRight == self.bottomRight
            && self.bottomRight == self.bottomLeft
    }
}

extension Corners where Value: Numeric {
    static var zero: Corners {
        return Corners(topLeft: 0, topRight: 0, bottomLeft: 0, bottomRight: 0)
    }
}

extension Corners: CustomDebugStringConvertible where Value: Equatable {
    var debugDescription: String {
        if isUniform {
            return "{ \(topLeft) }"
        } else {
            return "{ tL: \(topLeft), tR: \(topRight), bL: \(bottomLeft), bR: \(bottomRight) }"
        }
    }
}
