//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

extension UIImage {
    func resized(to newSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0);
        
        self.draw(in: CGRect(origin: CGPoint.zero, size: CGSize(width: newSize.width, height: newSize.height)))
        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
    
    func tiled(to newSize: CGSize, patternPhase: CGSize = .zero) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0);
        
        let ctx = UIGraphicsGetCurrentContext()
        
        let tileableImage = self.resizableImage(
            withCapInsets: .zero,
            resizingMode: .tile
        )
        
        let pattern = UIColor(patternImage: tileableImage)
        ctx?.setFillColor(pattern.cgColor)
        ctx?.setPatternPhase(patternPhase)
        ctx?.fill(CGRect(origin: .zero, size: newSize))
        
        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
}
