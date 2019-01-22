//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

#if os(iOS)
typealias Font = UIFont
typealias Image = UIImage
#else
//typealias Font = NSFont
#endif

/// Given a FontFamily and a size, it will return a font
typealias FontProvider = (FontFamily, Double) -> Font

/// All things platform-specific that are needed
struct IncitoRenderer {
    /// given a font family and a size it returns a Font
    var fontProvider: FontProvider
    /// given an image URL it returns the image in a completion handler.
    // TODO: way to cancel image loads?
    var imageViewLoader: (ImageViewLoadRequest) -> Void
    
    // TODO: not like this.
    var theme: Theme?
}

/// Represents a request for a url-based image, and provides the UIView into which the image was rendered.
struct ImageViewLoadRequest {
    let url: URL
    let transform: ((UIImage) -> UIImage)?
    let completion: (UIImageView?) -> Void
}

// MARK: - Sizing

/// Returns a function that, when given some viewProperties, returns a function that
func uiKitViewSizer(fontProvider: @escaping FontProvider, textDefaults: TextViewDefaultProperties) -> (ViewProperties) -> IntrinsicSizer {
    return { view in
        return { constraintSize in
            switch view.type {
            case let .text(text):
                let attrString = text.attributedString(
                    fontProvider: fontProvider,
                    defaults: textDefaults
                )
                let size = attrString.size(within: constraintSize)
                return Size(width: size.width, height: size.height)
            default:
                return Size(width: nil, height: nil)
            }
        }
    }
}

extension TextViewProperties {
    func attributedString(fontProvider: FontProvider, defaults: TextViewDefaultProperties) -> NSAttributedString {
        
        let fontFamily = self.fontFamily + defaults.fontFamily
        let textSize = self.textSize ?? defaults.textSize
        let textColor = self.textColor ?? defaults.textColor
        let lineHeightMultiplier = CGFloat(self.lineHeightMultiplier ?? defaults.lineHeightMultiplier)
        let alignment = (self.textAlignment ?? .left).nsTextAlignment
        
        var string = self.text
        if self.allCaps {
            string = string.uppercased()
        }
        
        if self.preventWidow {
            string = string.withoutWidows
        }
        
        let font = fontProvider(fontFamily, textSize)
        
        /*
         There are 2 problems when getting multi-line text rendered on iOS to be sized/positioned the same as on web - calculating the correct scaled line-height, and vertically-aligning the text within the lines correctly
         On web the lineheight is based on the pointSize of the font (not the actual `font.lineHeight`) * line-height-multiplier.
         If we apply the lineHeightMultiplier directly to the `paragraphStyle.lineHeightMultiple`, it ends up scaling the font.lineHeight _and_ the baselineOffset, and so ends up massively oversized.
         Instead we calculate the maxLineHeight using the pointSize, like on web, and use that as a min/max lineheight constraint on the paragraph style.
         
         For vertical positioning, on web the text is centered within each line, while on iOS it is bottom-aligned (with the bottom of the descender placed at the bottom of the line).
         If we want to center it we need to modify the baseline offset to center the glyphs (using the possibly larger `font.lineHeight`) within the (possibly smaller, point-size-based) maxLineHeight-sized line.
         */
        let maxLineHeight = floor(font.pointSize * lineHeightMultiplier)
        let baselineOffset: CGFloat = ((maxLineHeight / 2) - (font.lineHeight / 2)) / 2
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 0
        paragraphStyle.alignment = alignment
        paragraphStyle.maximumLineHeight = maxLineHeight
        paragraphStyle.minimumLineHeight = maxLineHeight
        
        if self.maxLines == 1 {
            paragraphStyle.lineBreakMode = .byClipping
        } else {
            paragraphStyle.lineBreakMode = .byWordWrapping
        }
        
        let attrStr = NSMutableAttributedString(
            string: string,
            attributes: [.foregroundColor: textColor.uiColor,
                         .font: font,
                         .baselineOffset: baselineOffset,
                         .paragraphStyle: paragraphStyle
            ]
        )
        
        for span in self.spans {
            
            let spanAttrs: [NSAttributedString.Key: Any] = {
                switch span.name {
                case .superscript:
                    return [
                        .baselineOffset: floor(textSize * 0.3),
                        .font: fontProvider(fontFamily, ceil(textSize * 0.6))
                    ]
                }
            }()
            
            attrStr.addAttributes(
                spanAttrs,
                range: NSRange(location: span.start,
                               length: span.end - span.start)
            )
        }
        
        return attrStr
    }
}

extension NSAttributedString {
    func size(within constraintSize: Size<Double?>) -> Size<Double> {
        
        let boundingBox = self.boundingRect(
            with: CGSize(
                width: constraintSize.width ?? .greatestFiniteMagnitude,
                height: constraintSize.height ?? .greatestFiniteMagnitude
            ),
            options: [.usesLineFragmentOrigin],
            context: nil)
        
        return Size(
            width: ceil(Double(boundingBox.size.width)),
            height: ceil(Double(boundingBox.size.height))
        )
    }
}

extension UIImageView {
    func applyBackground(
        position: BackgroundImage.Position,
        scalingType: BackgroundImage.ScaleType,
        tilingMode: BackgroundImage.TileMode
        ) {
        
        let containerSize = self.bounds.size
        let imageSize = (self.image?.size ?? .zero)
        
        // calculate how much the image needs to be scaled to fill or fit the container, depending on the scale type
        let fitFillScale: CGFloat = {
            if containerSize.width == 0 || containerSize.height == 0 || imageSize.width == 0 || imageSize.height == 0 {
                return 1
            }
            switch scalingType {
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
        
        if tilingMode != .none && scalingType != .centerCrop {
            
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
        self.layer.contentsGravity = position.contentsGravity(isFlipped: self.layer.contentsAreFlipped())
    }
}
