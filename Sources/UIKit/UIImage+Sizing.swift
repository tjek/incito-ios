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
    
    func resized(scalingType: BackgroundImage.ScaleType, into containerSize: CGSize, scale: CGFloat = 0) -> UIImage {
        let imageSize = self.size
        let imagePxSize = CGSize(width: imageSize.width * self.scale, height: imageSize.height * self.scale)
        
        // calculate how much the image needs to be scaled to fill or fit the container, depending on the scale type
        let fitFillScale: CGFloat = {
            if containerSize.width == 0 || containerSize.height == 0 || imageSize.width == 0 || imageSize.height == 0 {
                return 1
            }
            switch scalingType {
            case .centerCrop:
                // fill container
                let scaleX = imageSize.width / containerSize.width
                let scaleY = imageSize.height / containerSize.height
                return min(scaleX, scaleY)
                
            case .centerInside:
                // fit container
                let scaleX = imageSize.width / containerSize.width
                let scaleY = imageSize.height / containerSize.height
                return max(scaleX, scaleY)
                
            case .none:
                // original size
                return 1
            }
        }()
        
        if fitFillScale == 1 {
            return self
        } else {
            let targetSize = CGSize(
                width: imageSize.width / fitFillScale,
                height: imageSize.height / fitFillScale
            )
            let actualScale = scale == 0 ? UIScreen.main.scale : scale
            let targetPxSize = CGSize(width: targetSize.width * actualScale, height: targetSize.height * actualScale)
            
            // check if this image's pixel size matches the desired pixel size of the container
            if targetPxSize == imagePxSize {
                return self
            }
            
            return self.resized(to: targetSize, scale: scale)
        }
    }
}
