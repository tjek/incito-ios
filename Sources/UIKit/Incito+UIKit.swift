//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit
import GenericGeometry

#if os(iOS)
typealias Font = UIFont
typealias Image = UIImage
#else
//typealias Font = NSFont
#endif

/// Given a FontFamily and a size, it will return a font
typealias FontProvider = (FontFamily, Double, TextStyle) -> Font

/// All things platform-specific that are needed
struct IncitoRenderer {
    /// given a font family and a size it returns a Font
    var fontProvider: FontProvider
    /// given an image URL it returns the image in a completion handler.
    var imageViewLoader: (ImageViewLoadRequest) -> Void
    
    // TODO: not like this.
    var theme: Theme?
}

/// Represents a request for a url-based image, and provides the UIView into which the image was rendered.
struct ImageViewLoadRequest {
    let url: URL
    let containerSize: CGSize
    let transform: ((UIImage) -> UIImage)?
    let stillVisibleCheck: () -> Bool
    let completion: (UIImageView?) -> Void
}

// MARK: - Sizing

/// Returns a function that, when given some viewProperties, returns a function that calculates the intrinsic size of a view within some constraints.
func uiKitViewSizer(fontProvider: @escaping FontProvider, textDefaults: TextViewDefaultProperties) -> (ViewProperties) -> IntrinsicSizer {
    return { view in
        return { constraintSize in
            switch view.type {
            case let .text(text):
                let attrString = text.attributedString(
                    fontProvider: fontProvider,
                    defaults: textDefaults,
                    truncateSingleLines: false
                )
                // if text is a single line then dont apply constraints to it horizontally
                let size = attrString.size(
                    within: text.maxLines == 1 ? Size(width: nil, height: nil) : constraintSize
                )
                return Size(width: size.width, height: size.height)
            case let .video(video):
                return Size(width: video.videoSize?.width,
                            height: video.videoSize?.height)
                
            case let .videoEmbed(videoEmbed):
                return Size(width: videoEmbed.videoSize?.width,
                            height: videoEmbed.videoSize?.height)
                
            default:
                return Size(width: nil, height: nil)
            }
        }
    }
}

extension Shadow {
    var nsShadow: NSShadow {
        
        let shadow = NSShadow()
        shadow.shadowOffset = self.offset.cgSize
        shadow.shadowBlurRadius = CGFloat(self.radius)
        shadow.shadowColor = self.color.uiColor
        
        return shadow
    }
}
