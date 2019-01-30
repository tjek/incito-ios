//: [Previous](@previous)

import UIKit
import PlaygroundSupport

struct BackgroundImage {
    enum ScaleType: String, Decodable {
        case none // original size
        case centerCrop = "center_crop" // fill
        case centerInside = "center_inside" // fit
    }
    
    enum TileMode: String, Decodable {
        case none
        case repeatX = "repeat_x"
        case repeatY = "repeat_y"
        case repeatXY = "repeat"
    }
    
    enum Position: String, Decodable {
        case leftTop = "left_top"
        case leftCenter = "left_center"
        case leftBottom = "left_bottom"
        case centerTop = "center_top"
        case centerCenter = "center_center"
        case centerBottom = "center_bottom"
        case rightTop = "right_top"
        case rightCenter = "right_center"
        case rightBottom = "right_bottom"
    }
    
    var source: URL
    var scale: ScaleType
    var position: Position
    var tileMode: TileMode
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


extension UIImageView {
    func applyBackgroundImage(
        bgImage: BackgroundImage
        ) {
        let containerSize = self.bounds.size
        
        guard containerSize != .zero else {
            fatalError("Container Must not be zero-sized")
        }
        
        let imageSize = (self.image?.size ?? .zero)

        // calculate how much the image needs to be scaled to fill or fit the container, depending on the scale type
        let fitFillScale: CGFloat = {
            switch bgImage.scale {
            case .centerCrop:
                // fill container. No tiling necessary.
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

        if bgImage.tileMode != .none && bgImage.scale != .centerCrop {
            
            // get the size of the image if it were repeated in a specific access, fitting into the containerSize
            let tiledImageSize: CGSize = {
                var size = containerSize
                switch bgImage.tileMode {
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
                    switch bgImage.position {
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
                    switch bgImage.position {
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
            
            var image = self.image
            
            // As the scaling needs to be applied before the tiling, we need to scale the image first
            if fitFillScale != 1 && fitFillScale != 0 {
                image = image?.resized(to: CGSize(
                    width: imageSize.width / fitFillScale,
                    height: imageSize.height / fitFillScale)
                )
            }
            
            // generate an image that is tiled to fill the desired size, using the specified pattern phase.
            image = image?.tiled(
                to: tiledImageSize,
                patternPhase: patternPhase
            )

            self.image = image
            
        } else {
            // if no tiling, or if fill (so no tiling visible)
            
            let imageScale = self.image?.scale ?? 1
            
            self.layer.contentsScale = fitFillScale * imageScale
        }
        // use gravity to define the position
        self.layer.contentsGravity = bgImage.position.contentsGravity(isFlipped: self.layer.contentsAreFlipped())
    }
}


let containerView = UIView()
containerView.backgroundColor = .orange
containerView.frame = CGRect(x: 10, y: 10, width: 480, height: 300)

let bigImg = UIImage(named: "laptop_718x506.png")!
let smallImg = bigImg.resized(to: CGSize(width: 150, height: round((150/718) * 506)))

let imageView = UIImageView(image: bigImg)
//let imageView = UIImageView(image: smallImg)
imageView.backgroundColor = UIColor.red.withAlphaComponent(0.2)
imageView.clipsToBounds = true
//imageView.alpha = 0.7

containerView.addSubview(imageView)
imageView.frame = containerView.bounds
containerView.clipsToBounds = false

let bgImage = BackgroundImage(
    source: URL(string: "foo.bar")!,
    scale: .none,
    position: .rightBottom,
    tileMode: .repeatXY
)

imageView.applyBackgroundImage(
    bgImage: bgImage
)

let c = UIView()
c.frame = CGRect(x: 0, y: 0, width: 500, height: 500)
c.backgroundColor = .white
c.addSubview(containerView)

PlaygroundPage.current.liveView = c
