//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

extension Color {
    var uiColor: UIColor {
        return UIColor(hex: self.hexVal) ?? .clear
    }
}

extension Point {
    init(cgPoint: CGPoint) {
        self.init(x: Double(cgPoint.x), y: Double(cgPoint.y))
    }
    var cgPoint: CGPoint {
        return CGPoint(x: x, y: y)
    }
}

extension Size {
    init(cgSize: CGSize) {
        self.init(width: Double(cgSize.width), height: Double(cgSize.height))
    }
    var cgSize: CGSize {
        return CGSize(width: width, height: height)
    }
}

extension Rect {
    init(cgRect: CGRect) {
        self.init(origin: Point(cgPoint: cgRect.origin),
                  size: Size(cgSize: cgRect.size))
    }
    var cgRect: CGRect {
        return CGRect(x: origin.x, y: origin.y, width: size.width, height: size.height)
    }
}
