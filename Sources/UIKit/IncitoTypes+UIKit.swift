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
    public var uiColor: UIColor {
        return UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
    }
}

extension Point where Value == Double {
    init(cgPoint: CGPoint) {
        self.init(x: Double(cgPoint.x), y: Double(cgPoint.y))
    }
    var cgPoint: CGPoint {
        return CGPoint(x: x, y: y)
    }
}

extension Size where Value == Double {
    init(cgSize: CGSize) {
        self.init(width: Double(cgSize.width), height: Double(cgSize.height))
    }
    var cgSize: CGSize {
        return CGSize(width: width, height: height)
    }
}

extension Rect where Value == Double {
    init(cgRect: CGRect) {
        self.init(origin: Point(cgPoint: cgRect.origin),
                  size: Size(cgSize: cgRect.size))
    }
    var cgRect: CGRect {
        return CGRect(x: origin.x, y: origin.y, width: size.width, height: size.height)
    }
}

extension TextViewProperties.TextAlignment {
    var nsTextAlignment: NSTextAlignment {
        switch self {
        case .left: return .left
        case .right: return .right
        case .center: return .center
        }
    }
}

extension CALayer {
    func applyShadow(_ shadow: Shadow) {
        shadowColor = shadow.color.uiColor.cgColor
        shadowRadius = CGFloat(shadow.radius)
        shadowOffset = shadow.offset.cgSize
        shadowOpacity = 1
    }
}

extension BackgroundImage.Position {
    func contentsGravity(isFlipped: Bool) -> CALayerContentsGravity {
        switch self {
        case .leftTop:
            return isFlipped ? .bottomLeft : .topLeft
        case .leftCenter:
            return .left
        case .leftBottom:
            return isFlipped ? .topLeft : .bottomLeft
        case .centerTop:
            return isFlipped ? .bottom : .top
        case .centerCenter:
            return .center
        case .centerBottom:
            return isFlipped ? .top : .bottom
        case .rightTop:
            return isFlipped ? .bottomRight : .topRight
        case .rightCenter:
            return .right
        case .rightBottom:
            return isFlipped ? .topRight : .bottomRight
        }
    }
}

extension Transform where Value == Double {
    var affineTransform: CGAffineTransform {
        return CGAffineTransform.identity
            .translatedBy(x: CGFloat(origin.x), y: CGFloat(origin.y))
            .translatedBy(x: CGFloat(translate.x), y: CGFloat(translate.y))
            .rotated(by: CGFloat(rotate))
            .scaledBy(x: CGFloat(scale), y: CGFloat(scale))
            .translatedBy(x: CGFloat(-origin.x), y: CGFloat(-origin.y))
    }
}
