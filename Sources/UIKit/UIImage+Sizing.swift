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
    func resized(
        to newSize: CGSize,
        scale: CGFloat = 0.0
        ) -> UIImage {
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, scale);
        
        self.draw(in: CGRect(origin: CGPoint.zero, size: CGSize(width: newSize.width, height: newSize.height)))
        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    /// if `scale` is 0.0 it uses the devices scale
    func tiled(
        to newSize: CGSize,
        patternPhase: CGSize = .zero,
        scale: CGFloat = 0.0
        ) -> UIImage {
        
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
    
    /// If scale is 0.0 it uses the main screen scale
    func resized(
        scalingType: BackgroundImage.ScaleType,
        tilingMode: BackgroundImage.TileMode = .none,
        position: BackgroundImage.Position = .leftTop,
        into containerSize: CGSize,
        scale: CGFloat = 0.0
        ) -> UIImage {
        
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
        
        // if no tiling, or if fill (so no tiling visible)
        if tilingMode == .none || scalingType == .centerCrop {
        
            // no scaling needed, so just return self
            if fitFillScale == 1 {
                return self
            } else {
                let targetSize = CGSize(
                    width: imageSize.width / fitFillScale,
                    height: imageSize.height / fitFillScale
                )
                let actualScale = scale == 0 ? UIScreen.main.scale : scale
                let targetPxSize = CGSize(
                    width: targetSize.width * actualScale,
                    height: targetSize.height * actualScale
                )
                
                // check if this image's pixel size matches the desired pixel size of the container
                if targetPxSize == imagePxSize {
                    return self
                }
                
                return self.resized(to: targetSize, scale: scale)
            }
        } else {
            
            // get the size of the image if it were repeated in a specific access, fitting into the containerSize
            let tiledImageSize: CGSize = {
                var size = containerSize
                switch tilingMode {
                case .repeatX:
                    size.height = imageSize.height / fitFillScale
                case .repeatY:
                    size.width = imageSize.width / fitFillScale
                case .repeatXY, .none:
                    break
                }
                return size
            }()
            
            // calculate a pattern phase. this is used to position the repeating patterns within the repeating direction
            let patternPhase: CGSize = {
                let w: CGFloat = {
                    switch position {
                    case .leftTop,
                         .leftCenter,
                         .leftBottom:
                        return 0
                        
                    case .centerTop,
                         .centerCenter,
                         .centerBottom:
                        return (tiledImageSize.width / 2) - (imageSize.width / fitFillScale / 2)
                        
                    case .rightTop,
                         .rightCenter,
                         .rightBottom:
                        return tiledImageSize.width - (imageSize.width / fitFillScale)
                    }
                }()
                let h: CGFloat = {
                    switch position {
                    case .leftTop,
                         .centerTop,
                         .rightTop:
                        return 0
                        
                    case .leftCenter,
                         .centerCenter,
                         .rightCenter:
                        return (tiledImageSize.height / 2) - (imageSize.height / fitFillScale / 2)
                        
                    case .leftBottom,
                         .centerBottom,
                         .rightBottom:
                        return tiledImageSize.height - (imageSize.height / fitFillScale)
                    }
                }()
                
                return CGSize(width: w, height: h)
            }()
            
            var image = self
            
            // As the scaling needs to be applied before the tiling, we need to scale the image first
            if fitFillScale != 1 && fitFillScale != 0 {
                image = self.resized(to: CGSize(
                    width: imageSize.width / fitFillScale,
                    height: imageSize.height / fitFillScale)
                )
            }
            
            // generate an image that is tiled to fill the desired size, using the specified pattern phase.
            image = image.tiled(
                to: tiledImageSize,
                patternPhase: patternPhase
            )
            
            return image
        }
    }
}
