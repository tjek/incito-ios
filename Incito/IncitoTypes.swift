//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

typealias FontAssetName = String
typealias FontFamily = [FontAssetName]

struct Color: Equatable {
    // 0-1 Doubles
    var r, g, b, a: Double
}

// MARK: - Dimensions

enum Unit {
    case pts(Double)
    case percent(Double)
}

enum LayoutSize {
    case unit(Unit)
    case wrapContent
    case matchParent
}

struct Edges<Value> {
    var top, left, bottom, right: Value
}

extension Edges: Equatable where Value: Equatable {
    static func == (lhs: Edges<Value>, rhs: Edges<Value>) -> Bool {
        return lhs.top == rhs.top
            && lhs.left == rhs.left
            && lhs.bottom == rhs.bottom
            && lhs.right == rhs.right
    }
}
extension Edges {
    init(_ val: Value) {
        self.init(top: val, left: val, bottom: val, right: val)
    }
}

typealias UnitEdges = Edges<Unit>
extension Edges where Value == Unit {
    static let zero = Edges(.pts(0))
}
extension Edges where Value == Double {
    static let zero = Edges(0)
}

struct Corners<Value> {
    var topLeft, topRight, bottomLeft, bottomRight: Value
}

extension Corners: Equatable where Value: Equatable {
    static func == (lhs: Corners<Value>, rhs: Corners<Value>) -> Bool {
        return lhs.topLeft == rhs.topLeft
            && lhs.topRight == rhs.topRight
            && lhs.bottomLeft == rhs.bottomLeft
            && lhs.bottomRight == rhs.bottomRight
    }
    
    /// If all corner values are the same
    var isUniform: Bool {
        return self.topLeft == self.topRight
            && self.topRight == self.bottomRight
            && self.bottomRight == self.bottomLeft
    }
}

extension Corners {
    init(_ val: Value) {
        self.init(topLeft: val, topRight: val, bottomLeft: val, bottomRight: val)
    }
}
typealias UnitCorners = Corners<Unit>

extension Corners where Value == Unit {
    static let zero = Corners(.pts(0))
}
extension Corners where Value == Double {
    static let zero = Corners(0)
}

// MARK: - Layout

struct Point<Value> {
    var x, y: Value
}
struct Size<Value> {
    var width, height: Value
}
struct Rect<Value> {
    var origin: Point<Value>
    var size: Size<Value>
}

extension Point: Equatable where Value: Equatable {
    static func == (lhs: Point<Value>, rhs: Point<Value>) -> Bool {
        return lhs.x == rhs.x
            && lhs.y == rhs.y
    }
}
extension Point where Value == Double {
    static let zero = Point(x: 0, y: 0)
}

extension Size: Equatable where Value: Equatable {
    static func == (lhs: Size<Value>, rhs: Size<Value>) -> Bool {
        return lhs.width == rhs.width
            && lhs.height == rhs.height
    }
}

extension Size where Value == Double {
    static let zero = Size(width: 0, height: 0)
}

extension Rect: Equatable where Value: Equatable {
    static func == (lhs: Rect<Value>, rhs: Rect<Value>) -> Bool {
        return lhs.origin == rhs.origin
            && lhs.size == rhs.size
    }
}

extension Rect where Value == Double {
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
    func absolute(in parent: Size<Double>) -> Edges<Double> {
        return .init(
            top: self.top.absolute(in: parent.height),
            left: self.left.absolute(in: parent.width),
            bottom: self.bottom.absolute(in: parent.height),
            right: self.right.absolute(in: parent.width)
        )
    }
}
extension Edges where Value == Unit? {
    func absolute(in parent: Size<Double>) -> Edges<Double?> {
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

// MARK: Debug printing

extension Edges: CustomDebugStringConvertible where Value: Equatable {
    var debugDescription: String {
        if top == left && left == bottom && bottom == right {
            return "{ \(top) }"
        } else {
            return "{ t: \(top), l: \(left), b: \(bottom), r: \(right) }"
        }
    }
}

extension Size: CustomDebugStringConvertible {
    var debugDescription: String {
        return "{ w:\(width), h:\(height) }"
    }
}

extension Point: CustomDebugStringConvertible {
    var debugDescription: String {
        return "{ x:\(x), y:\(y) }"
    }
}
