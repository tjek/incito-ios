//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2017 ShopGun. All rights reserved.

import UIKit

extension UIColor {

    /// a transparent red, useful for debugging
    public static var debug: UIColor { return UIColor.red.withAlphaComponent(0.2) }

    /// make any color transparent, so that it is useful for debugging
    public var debug: UIColor { return withAlphaComponent(0.2) }
}

extension UIView {
    public func debugify() {
        backgroundColor = .debug
        for subview in subviews {
            subview.debugify()
        }
    }
}
