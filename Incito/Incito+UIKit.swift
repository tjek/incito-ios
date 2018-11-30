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
typealias ImageLoader = (URL, @escaping (Image?) -> Void) -> Void

// All things platform-specific that are needed
struct IncitoRenderer {
    /// given a font family and a size it returns a Font
    var fontProvider: FontProvider
    /// given an image URL it returns the image in a completion handler.
    // TODO: way to cancel image loads?
    var imageLoader: ImageLoader
    
    // TODO: not like this.
    var theme: Theme?
}

// MARK: -

class IncitoDebugView: UIView {
    let label = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
//        addSubview(label)
//
//        label.translatesAutoresizingMaskIntoConstraints = false
//        NSLayoutConstraint.activate([
//            label.centerXAnchor.constraint(equalTo: self.centerXAnchor),
//            label.centerYAnchor.constraint(equalTo: self.centerYAnchor)
//            ])
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - View Building

extension UIView {
    // build a UIView based on a layoutNode and it's children
    static func build(_ layout: LayoutNode, renderer: IncitoRenderer, depth: Int = 0, maxDepth: Int? = nil) -> (UIView, [ImageLoadRequest]) {
        
        let view: UIView
        // if the view needs to do an image load it populates this property
        var imageLoadRequests: [ImageLoadRequest] = []
        
        switch layout.view.type {
        case let .text(textProperties):
            view = .buildTextView(
                textProperties,
                textDefaults: renderer.theme?.textDefaults ?? .empty,
                styleProperties: layout.view.style,
                fontProvider: renderer.fontProvider,
                in: layout.rect
            )
        case let .image(imageProperties):
            let (imgView, imgReq) = UIView.buildImageView(
                imageProperties,
                styleProperties: layout.view.style,
                in: layout.rect
            )
            imageLoadRequests.append(imgReq)
            view = imgView
        case .view,
             .absoluteLayout,
             .flexLayout:
            view = .buildPassthruView(
                styleProperties: layout.view.style,
                in: layout.rect
            )
        default:
            let dbgView = IncitoDebugView()
            dbgView.isHidden = true
            //        dbgView.label.text = layout.view.id
            view = dbgView
        }
        
        view.frame = layout.rect.cgRect
        
        // must be called after frame otherwise round-rect clipping path is not sized properly
        let bgImageReq = view.apply(styleProperties: layout.view.style, renderer: renderer, in: layout.rect)
        
        if let bgReq = bgImageReq {
            imageLoadRequests.append(bgReq)
        }
        
        // skip children if reached the max depth
        if depth < maxDepth ?? .max {
            for childNode in layout.children {
                let (childView, childImgReqs) = UIView.build(
                    childNode,
                    renderer: renderer,
                    depth: depth + 1,
                    maxDepth: maxDepth
                )
                view.addSubview(childView)
                
                imageLoadRequests += childImgReqs
            }
        }
        
        return (view, imageLoadRequests)
    }
    
    static func buildTextView(_ textProperties: TextViewProperties, textDefaults: TextViewDefaultProperties, styleProperties: StyleProperties, fontProvider: FontProvider, in rect: Rect) -> UIView {
        
        let label = UILabel()
        
        let attributedString = textProperties.attributedString(
            fontProvider: fontProvider,
            defaults: textDefaults
        )
        
        label.attributedText = attributedString
        label.numberOfLines = textProperties.maxLines
        
        label.textAlignment = (textProperties.textAlignment ?? .left).nsTextAlignment
        
        label.backgroundColor = .clear
        
        return label
    }
    
    static func buildImageView(_ imageProperties: ImageViewProperties, styleProperties: StyleProperties, in rect: Rect) -> (UIView, ImageLoadRequest) {
        
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        
        let imageLoadReq = ImageLoadRequest(url: imageProperties.source) { [weak imageView] loadedImage in
            
            guard let imgView = imageView else { return }
            
            UIView.transition(
                with: imgView,
                duration: 0.2,
                options: .transitionCrossDissolve,
                animations: {
                    if let img = loadedImage {
                        imgView.image = img
                    } else {
                        imgView.backgroundColor = .red
                    }            },
                completion: nil
            )
        }
        
        return (imageView, imageLoadReq)
    }
    
    static func buildPassthruView(styleProperties: StyleProperties, in rect: Rect) -> UIView {
        let view = UIView()
        return view
    }
}

struct ImageLoadRequest {
    let url: URL
    let completion: (Image?) -> Void
}

extension UIView {
    func apply(styleProperties style: StyleProperties, renderer: IncitoRenderer, in rect: Rect) -> ImageLoadRequest? {
        
        // apply the layout.view properties
        backgroundColor = style.backgroundColor?.uiColor ?? .clear
        clipsToBounds = style.clipsChildren
        
        var imgReq: ImageLoadRequest? = nil
        if let bgImage = style.backgroundImage {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFill
            imageView.frame = self.bounds
            imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.addSubview(imageView)
            
            imgReq = ImageLoadRequest(url: bgImage.source) { [weak imageView] loadedImage in
                if let img = loadedImage {
                    imageView?.image = img
                } else {
                    imageView?.backgroundColor = .red
                }
            }
        }
        
        // Use the smallest dimension when calculating relative corners.
        let cornerRadius = style.cornerRadius.absolute(in: min(rect.size.width, rect.size.height) / 2)
        
        if cornerRadius != Corners<Double>.zero {
            if cornerRadius.topLeft == cornerRadius.topRight && cornerRadius.bottomLeft == cornerRadius.bottomRight &&
                cornerRadius.topLeft == cornerRadius.bottomLeft {
                
                layer.cornerRadius = CGFloat(cornerRadius.topLeft)
            } else {
                roundCorners(
                    topLeft: CGFloat(cornerRadius.topLeft),
                    topRight: CGFloat(cornerRadius.topRight),
                    bottomLeft: CGFloat(cornerRadius.bottomLeft),
                    bottomRight: CGFloat(cornerRadius.bottomRight)
                )
            }
        }
        
        self.transform = self.transform
            .rotated(by: CGFloat(style.transform.rotate))
            .scaledBy(x: CGFloat(style.transform.scale), y: CGFloat(style.transform.scale))
        //        transform.translatedBy(x: style.transform.translateX,
        //                               y: style.transform.translateY)

        return imgReq
    }
}

// MARK: - Sizing

let uiKitViewSizer: (@escaping FontProvider, TextViewDefaultProperties) -> ViewSizer = { fontProvider, textDefaults in
    return { view, constraintSize in
        switch view.type {
        case let .text(text):
            return sizeForText(
                text,
                maxWidth: constraintSize.width,
                fontProvider: fontProvider,
                defaults: textDefaults
            )
        default:
            return .zero
        }
    }
}

extension TextViewProperties {
    func attributedString(fontProvider: FontProvider, defaults: TextViewDefaultProperties) -> NSAttributedString {
        
        let fontFamily = self.fontFamily + defaults.fontFamily
        let textSize = self.textSize ?? defaults.textSize
        let textColor = self.textColor ?? defaults.textColor
        let lineSpacingMultiplier = self.lineSpacingMultiplier ?? defaults.lineSpacingMultiplier
        let alignment = (self.textAlignment ?? .left).nsTextAlignment
        
        var string = self.text
        if self.allCaps {
            string = string.uppercased()
        }
        
        let font = fontProvider(fontFamily, textSize)
        
        // TODO: why this magic number?!
        let scaleFactor: CGFloat = 3
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = (CGFloat(lineSpacingMultiplier) - 1) / scaleFactor + 1
        paragraphStyle.alignment = alignment
        
        let attrStr = NSMutableAttributedString(
            string: string,
            attributes: [.foregroundColor: textColor.uiColor,
                         .font: font,
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

func sizeForText(_ textProperties: TextViewProperties, maxWidth: Double, fontProvider: FontProvider, defaults: TextViewDefaultProperties) -> Size {
    
    let attrString = textProperties.attributedString(
        fontProvider: fontProvider,
        defaults: defaults)
    
    let boundingBox = attrString.boundingRect(
        with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
        options: .usesLineFragmentOrigin,
        context: nil)
    
    return Size(
        width: ceil(Double(boundingBox.size.width)),
        height: ceil(Double(boundingBox.size.height))
    )
}
