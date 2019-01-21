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
typealias ImageViewLoader = (URL, @escaping (UIView?) -> Void) -> Void

/// All things platform-specific that are needed
struct IncitoRenderer {
    /// given a font family and a size it returns a Font
    var fontProvider: FontProvider
    /// given an image URL it returns the image in a completion handler.
    // TODO: way to cancel image loads?
    var imageViewLoader: ImageViewLoader
    
    // TODO: not like this.
    var theme: Theme?
}

/// Represents a request for a url-based image, and provides the UIView into which the image was rendered.
struct ImageViewLoadRequest {
    let url: URL
    let completion: (UIView?) -> Void
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
        paragraphStyle.lineBreakMode = .byTruncatingTail
        
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
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            context: nil)
        
        return Size(
            width: ceil(Double(boundingBox.size.width)),
            height: ceil(Double(boundingBox.size.height))
        )
    }
}
