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
    
    static func buildTextView(_ textProperties: TextViewProperties, textDefaults: TextViewDefaultProperties, styleProperties: StyleProperties, fontProvider: FontProvider, in rect: Rect<Double>) -> UIView {
        
        let label = UILabel()
        
        // TODO: cache these values from when doing the layout phase
        let attributedString = textProperties.attributedString(
            fontProvider: fontProvider,
            defaults: textDefaults
        )
        
        label.attributedText = attributedString
        label.numberOfLines = textProperties.maxLines
        
        label.textAlignment = (textProperties.textAlignment ?? .left).nsTextAlignment
        
        label.backgroundColor = .clear
        
        // labels are vertically aligned in incito, so add to a container view
        let container = UIView()
        container.frame = rect.cgRect
        
        container.addSubview(label)
        
        let textHeight = label.sizeThatFits(container.bounds.size).height
        label.frame = CGRect(origin: .zero,
                             size: CGSize(width: container.bounds.size.width,
                                          height: textHeight))
        label.autoresizingMask = [.flexibleBottomMargin, .flexibleWidth]

        return container
    }
    
    static func buildImageView(_ imageProperties: ImageViewProperties, styleProperties: StyleProperties, in rect: Rect<Double>) -> (UIView, ImageLoadRequest) {
        
        let imageView = UIImageView()
        imageView.contentMode = .scaleToFill
        
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
    
    static func buildPassthruView(styleProperties: StyleProperties, in rect: Rect<Double>) -> UIView {
        let view = UIView()
        return view
    }
}

struct ImageLoadRequest {
    let url: URL
    let completion: (Image?) -> Void
}

extension UIView {
    func apply(styleProperties style: StyleProperties, renderer: IncitoRenderer, in rect: Rect<Double>) -> ImageLoadRequest? {
        
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
        
        // TODO: Not like this
        let parentSize = superview?.bounds.size ?? frame.size
        
        // TODO: use real anchor point
        setAnchorPoint(anchorPoint: CGPoint.zero)
        
        self.transform = self.transform
            .translatedBy(x: CGFloat(style.transform.translateX.absolute(in: Double(parentSize.width))),
                          y: CGFloat(style.transform.translateY.absolute(in: Double(parentSize.height))))
            .scaledBy(x: CGFloat(style.transform.scale), y: CGFloat(style.transform.scale))
            .rotated(by: CGFloat(style.transform.rotate))
        
        return imgReq
    }
}
extension UIView{
    func setAnchorPoint(anchorPoint: CGPoint) {
        
        var newPoint = CGPoint(x: self.bounds.size.width * anchorPoint.x, y: self.bounds.size.height * anchorPoint.y)
        var oldPoint = CGPoint(x: self.bounds.size.width * self.layer.anchorPoint.x, y: self.bounds.size.height * self.layer.anchorPoint.y)
        
        newPoint = newPoint.applying(self.transform)
        oldPoint = oldPoint.applying(self.transform)
        
        var position : CGPoint = self.layer.position
        
        position.x -= oldPoint.x
        position.x += newPoint.x;
        
        position.y -= oldPoint.y;
        position.y += newPoint.y;
        
        self.layer.position = position;
        self.layer.anchorPoint = anchorPoint;
    }
}
// MARK: - Sizing

let uiKitViewSizer: (@escaping FontProvider, TextViewDefaultProperties) -> (ViewProperties) -> IntrinsicSizer = { fontProvider, textDefaults in
    return { view in
        return { constraintSize in
            switch view.type {
            case let .text(text):
                let size = sizeForText(
                    text,
                    constraintSize: constraintSize,
                    fontProvider: fontProvider,
                    defaults: textDefaults
                )
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
        let lineSpacingMultiplier = CGFloat(self.lineSpacingMultiplier ?? defaults.lineSpacingMultiplier)
        let alignment = (self.textAlignment ?? .left).nsTextAlignment
        
        var string = self.text
        if self.allCaps {
            string = string.uppercased()
        }
        
        let font = fontProvider(fontFamily, textSize)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = lineSpacingMultiplier
        paragraphStyle.lineSpacing = 0
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

func sizeForText(_ textProperties: TextViewProperties, constraintSize: Size<Double?>, fontProvider: FontProvider, defaults: TextViewDefaultProperties) -> Size<Double> {
    
    let attrString = textProperties.attributedString(
        fontProvider: fontProvider,
        defaults: defaults)
    
    let boundingBox = attrString.boundingRect(
        with: CGSize(
            width: constraintSize.width ?? .greatestFiniteMagnitude,
            height: constraintSize.height ?? .greatestFiniteMagnitude
        ),
        options: .usesLineFragmentOrigin,
        context: nil)
    
    return Size(
        width: ceil(Double(boundingBox.size.width)),
        height: ceil(Double(boundingBox.size.height))
    )
}
