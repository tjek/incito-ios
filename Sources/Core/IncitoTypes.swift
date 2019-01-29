//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

public typealias FontAssetName = String
public typealias FontFamily = [FontAssetName]

public struct Color: Equatable {
    // 0-1 Doubles
    var r, g, b, a: Double
}

// MARK: - Dimensions

public enum Unit {
    case pts(Double)
    case percent(Double)
}

enum LayoutSize {
    case unit(Unit)
    case wrapContent
    case matchParent
}

typealias UnitEdges = Edges<Unit>
extension Edges where Value == Unit {
    static let zero = Edges(.pts(0))
}


typealias UnitCorners = Corners<Unit>
extension Corners where Value == Unit {
    static let zero = Corners(.pts(0))
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

extension Size where Value == Unit {
    func absolute(in size: Size<Double>) -> Size<Double> {
        return Size<Double>(
            width: width.absolute(in: size.width),
            height: height.absolute(in: size.height)
        )
    }
}

extension Point where Value == Unit {
    func absolute(in size: Size<Double>) -> Point<Double> {
        return Point<Double>(
            x: x.absolute(in: size.width),
            y: y.absolute(in: size.height)
        )
    }
}
extension Transform where Value == Unit {
    func absolute(viewSize: Size<Double>) -> Transform<Double> {
        return Transform<Double>(
            scale: self.scale,
            rotate: self.rotate,
            translate: self.translate.absolute(in: viewSize),
            origin: self.origin.absolute(in: viewSize)
        )
    }
}
