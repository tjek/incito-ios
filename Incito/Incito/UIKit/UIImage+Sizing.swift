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
    /// if `scale` is 0.0 it uses the devices scale
    func resized(to newSize: CGSize, scale: CGFloat = 0.0) -> UIImage {
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, scale);
        
        self.draw(in: CGRect(origin: CGPoint.zero, size: CGSize(width: newSize.width, height: newSize.height)))
        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    /// if `scale` is 0.0 it uses the devices scale
    func tiled(to newSize: CGSize, patternPhase: CGSize = .zero, scale: CGFloat = 0.0) -> UIImage {
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, scale);
        
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
