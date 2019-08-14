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

/**
 A UIView subclass for rendering attributedString text quickly.
 
 It will make sure that the line fragments match the desired lineHeight, and that the baseline offset within each linefragment is such that the text is vertically centered within each line (matching how CSS aligns the text)
 */
class AdjustedBaselineStringView: UIView, NSLayoutManagerDelegate {
    let desiredLineHeight: CGFloat
    let fontLineHeight: CGFloat
    let fontLeading: CGFloat
    let fontDescender: CGFloat
    
    private let textStorage: NSTextStorage
    private let layoutManager: NSLayoutManager
    private let textContainer: NSTextContainer
    
    var attributedText: NSAttributedString {
        set {
            textStorage.setAttributedString(newValue)
        }
        get {
            return textStorage
        }
    }
    
    init(attributedString: NSAttributedString, desiredLineHeight: CGFloat, fontLineHeight: CGFloat, fontLeading: CGFloat, fontDescender: CGFloat) {
        self.desiredLineHeight = desiredLineHeight
        self.fontLineHeight = fontLineHeight
        self.fontLeading = fontLeading
        self.fontDescender = fontDescender
        
        self.layoutManager = NSLayoutManager()
        self.textStorage = NSTextStorage(attributedString: attributedString)
        self.textContainer = NSTextContainer(size: .zero)
        self.textContainer.lineFragmentPadding = 0
        self.layoutManager.addTextContainer(self.textContainer)
        self.textStorage.addLayoutManager(self.layoutManager)
        
        super.init(frame: .zero)
        
        self.layoutManager.delegate = self
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        let glyphRange = self.layoutManager.glyphRange(for: self.textContainer)
        self.layoutManager.drawBackground(forGlyphRange: glyphRange, at: rect.origin)
        self.layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: rect.origin)
    }
    
    override var frame: CGRect {
        didSet {
            self.textContainer.size = frame.size
        }
    }
    
    override var bounds: CGRect {
        didSet {
            self.textContainer.size = bounds.size
        }
    }
    
    func layoutManager(
        _ layoutManager: NSLayoutManager,
        shouldSetLineFragmentRect lineFragmentRect: UnsafeMutablePointer<CGRect>,
        lineFragmentUsedRect: UnsafeMutablePointer<CGRect>,
        baselineOffset: UnsafeMutablePointer<CGFloat>,
        in textContainer: NSTextContainer,
        forGlyphRange glyphRange: NSRange
        ) -> Bool {
        
        var changed: Bool = false
        
        var rect = lineFragmentRect.pointee
        var usedRect = lineFragmentUsedRect.pointee
        
        // how many desired lines can we fit into this container
        let maxLineCount = floor(textContainer.size.height / desiredLineHeight)

        // how much space we have to use for this and all the remaining lines
        let remainingSpace = textContainer.size.height - rect.origin.y
        
        let newHeight: CGFloat
        
        // if more than 1 line of content, then adjust the fragment's size
        if maxLineCount > 1 {
            
            // This is the height that the layout system wants to give to a line of text.
            let systemFragmentHeight = desiredLineHeight + fontLeading
            
            // find an average height for all the lines that aren't the last line
            // This is because the last line _HAS_ to be the height the system decides
            // When it tries to fit the last line in the container it will just not draw the last line if there isnt enough room for it to be positioned.
            let averageNonBottomLineHeight = (textContainer.size.height - systemFragmentHeight) / (maxLineCount - 1)
            
            // adjust the height of the fragment
            newHeight = min(averageNonBottomLineHeight, remainingSpace)
        } else {
            newHeight = min(desiredLineHeight, remainingSpace)
        }
        
        changed = rect.size.height != newHeight ? true : changed
        
        rect.size.height = newHeight
        usedRect.size.height = rect.size.height
        
        lineFragmentRect.pointee = rect
        lineFragmentUsedRect.pointee = usedRect
        
        // how much the baseline needs to be offset to position the text in the center of the line fragment.
        // when `baselineOffset` is 0, the baseline of the text is aligned to the top (origin) of the line
        // so move the baseline to the middle of the fragment
        // then move down by half the lineHeight, and also by the descender
        let newBaselineOffset = (rect.midY - rect.origin.y) + (fontLineHeight / 2) + fontDescender

        changed = baselineOffset.pointee != newBaselineOffset ? true : changed
        
        baselineOffset.pointee = newBaselineOffset

        return changed
    }
}

extension UIView {
    
    func addTextView(
        textProperties: TextViewProperties,
        fontProvider: FontProvider,
        textDefaults: TextViewDefaultProperties,
        padding: Edges<Double>,
        intrinsicSize: Size<Double?>,
        clipsChildren: Bool
        ) {
        
        let containerInnerSize = self.bounds.inset(by: padding.uiEdgeInsets).size
        
        let font = textProperties.font(fontProvider: fontProvider, defaults: textDefaults)
        
        // TODO: cache these values from when doing the layout phase
        let attributedString = textProperties.attributedString(
            font: font,
            defaults: textDefaults,
            truncateSingleLines: clipsChildren
        )
        
        // it may not have an intrinsic height calculated yet (eg. if the view container has absolute height specified)
        // in that case, we need to calculate how big the
        let textSize: CGSize = {
            if clipsChildren {
                return containerInnerSize
            }
            
            if let h = intrinsicSize.height, let w = intrinsicSize.width {
                return CGSize(width: w, height: h)
            }
            
            // if text is a single line then dont apply constraints to it horizontally
            let fittingSize = attributedString.size(
                within: Size(width: textProperties.maxLines == 1 ? nil : Double(containerInnerSize.width), height: nil)
            )
            
            return CGSize(width: intrinsicSize.width ?? Double(ceil(fittingSize.width)),
                        height: intrinsicSize.height ?? Double(ceil(fittingSize.height)))
        }()
        
        var labelFrame = CGRect(
            origin: CGPoint(x: padding.left, y: padding.top),
            size: textSize
        )
        
        // position vertically - center if label is taller than than container
        if labelFrame.size.height > containerInnerSize.height {
            labelFrame.origin.y += (containerInnerSize.height - labelFrame.size.height) / 2
        }
        
        // position horizontally - if smaller than container then position using alignment
        if labelFrame.size.width < containerInnerSize.width {
            // TODO: support right-to-left systems, if text-alignment undefined
            switch textProperties.textAlignment ?? .left {
            case .left:
                break
            case .right:
                labelFrame.origin.x += containerInnerSize.width - labelFrame.size.width
            case .center:
                labelFrame.origin.x += (containerInnerSize.width / 2) - (labelFrame.size.width / 2)
            }
        }
        
        let label = AdjustedBaselineStringView(
            attributedString: attributedString,
            desiredLineHeight: font.pointSize * CGFloat(textProperties.lineHeightMultiplier ?? textDefaults.lineHeightMultiplier),
            fontLineHeight: font.lineHeight,
            fontLeading: font.leading,
            fontDescender: font.descender
        )
        
        label.backgroundColor = .clear
        if labelFrame.width > self.bounds.width ||
            labelFrame.height < self.bounds.height {
            label.clipsToBounds = false
        } else {
            label.clipsToBounds = true
        }
        
        label.frame = labelFrame
        
        self.insertSubview(label, at: 0)
    }    
}

extension TextViewProperties {
    
    func font(fontProvider: FontProvider, defaults: TextViewDefaultProperties) -> UIFont {
        
        let fontFamily = self.fontFamily + defaults.fontFamily
        let textSize = self.textSize ?? defaults.textSize
        let style = self.textStyle ?? .normal
        
        return fontProvider(fontFamily, textSize, style)
    }
    
    /**
     Builds an attributed string based on the TextViewProperties.
     
     This will apply font, alignment, lineheightMultiplier, textColor, span styling, widow-removal, and allCaps.
     
     It will not do anything to adjust the position of text line fragments within whatever renders the text - that is an NSLayoutManager problem.
     */
    func attributedString(fontProvider: FontProvider, defaults: TextViewDefaultProperties, truncateSingleLines: Bool) -> NSAttributedString {
        let font = self.font(fontProvider: fontProvider, defaults: defaults)
        return self.attributedString(font: font,
                                     defaults: defaults,
                                     truncateSingleLines: truncateSingleLines)
    }
    
    func attributedString(
        font: UIFont,
        defaults: TextViewDefaultProperties,
        truncateSingleLines: Bool
        ) -> NSAttributedString {
        
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
        
        /*
         CSS handles line-height multiplier differently to iOS
         
         In CSS, if _no_ `line-height` property is specified (or it's set to `normal`) it uses the lineHeight of the font (the same as iOS does).
         
         This is not, however, the same as setting the `line-height` to 1. In that case it uses the font's pont size as the line's height.
         
         To convert from iOS lineHeight to a CSS line-height of 1, we need the scaleFactor. When multiplied with the text properties' lineHeightMultiplier, we get a multiplier that give the same lineHeight as in CSS.
         */
        let lineHeightScaleFactor = (font.pointSize / font.lineHeight) // to go from css normal -> 1

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineHeightMultiple = lineHeightMultiplier * lineHeightScaleFactor

        if self.maxLines == 1 {
            paragraphStyle.lineBreakMode = truncateSingleLines ? .byTruncatingTail : .byClipping
        } else {
            paragraphStyle.lineBreakMode = .byWordWrapping
        }
        
        var attrs: [NSAttributedString.Key : Any] = [
            .foregroundColor: textColor.uiColor,
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        attrs[.shadow] = self.shadow?.nsShadow
        
        let attrStr = NSMutableAttributedString(
            string: string,
            attributes: attrs
        )
        
        let textSize = font.pointSize
        let superscriptFont = font.withSize(ceil(textSize * 0.6))
        
        for span in self.spans {
            
            let spanAttrs: [NSAttributedString.Key: Any] = {
                switch span.name {
                case .superscript:
                    return [
                        .baselineOffset: floor(textSize * 0.3),
                        .font: superscriptFont
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
    /**
     Calcualte the size that fits the receiver's text, given a size constraint. A nil-dimension means no constraint.
     */
    func size(within constraintSize: Size<Double?>) -> Size<Double> {
        
        let boundingBox = self.boundingRect(
            with: CGSize(
                width: constraintSize.width ?? .greatestFiniteMagnitude,
                height: constraintSize.height ?? .greatestFiniteMagnitude
            ),
            options: [.usesLineFragmentOrigin],
            context: nil)
        
        let size = Size(
            width: Double(ceil(boundingBox.size.width)),
            height: Double(ceil(boundingBox.size.height))
        )
        
        return size
    }
}
