//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

extension IncitoDocument: Decodable where ViewTreeNode == ViewProperties {
    
    enum CodingKeys: String, CodingKey {
        case id, version
        case rootView = "root_view"
        case theme, locale, meta
        case fontAssets = "font_assets"
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try c.decode(.id)
        self.version = try c.decode(.version)
        
        self.rootView = try c.decode(.rootView)
        
        self.locale = (try? c.decode(.locale)) ?? self.locale
        self.theme = (try? c.decode(.theme)) ?? self.theme
        self.meta = (try? c.decode(.meta)) ?? self.meta
        self.fontAssets = (try? c.decode(.fontAssets)) ?? self.fontAssets
    }
}

extension TreeNode: Decodable where T == ViewProperties {
    
    enum CodingKeys: CodingKey {
        case viewName, id, children
        /// This case defines all unknown payload keys.
        case properties(key: String)
        
        private static let knownKeys: [CodingKeys] = [.viewName, .id, .children]
        
        var stringValue: String {
            switch self {
            case .viewName: return "view_name"
            case .id: return "id"
            case .children: return "child_views"
            case .properties(let key): return key
            }
        }
        
        init?(stringValue: String) {
            if let key = CodingKeys.knownKeys.first(where: { stringValue == $0.stringValue }) {
                self = key
            } else {
                self = .properties(key: stringValue)
            }
        }
        
        var intValue: Int? { return Int(stringValue) }
        init?(intValue: Int) { self.init(stringValue: "\(intValue)") }
        
    }
    
    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        let propertiesContainer = try decoder.singleValueContainer()
        
        let viewType: ViewType = try {
            // Decode the type and type-specific properties
            let viewName: String? = try? c.decode(.viewName)
            switch viewName {
            case "AbsoluteLayout"?:
                return .absoluteLayout
            case "FlexLayout"?:
                let flexProperties = try propertiesContainer.decode(FlexLayoutProperties.self)
                return .flexLayout(flexProperties)
            case "TextView"?:
                let textProperties = try propertiesContainer.decode(TextViewProperties.self)
                return .text(textProperties)
            case "ImageView"?:
                let imageProperties = try propertiesContainer.decode(ImageViewProperties.self)
                return .image(imageProperties)
            case "VideoEmbedView"?:
                let videoEmbedProperties = try propertiesContainer.decode(VideoEmbedViewProperties.self)
                return .videoEmbed(videoEmbedProperties)
            case "VideoView"?:
                let videoProperties = try propertiesContainer.decode(VideoViewProperties.self)
                return .video(videoProperties)
            case "View"?,
                 nil:
                fallthrough
            default:
                return .view
            }
        }()
        
        self.init(value: ViewProperties(
            id: ViewProperties.Identifier.generate(),
            name: try c.decodeIfPresent(.id),
            type: viewType,
            style: (try? propertiesContainer.decode()) ?? .empty,
            layout: (try? propertiesContainer.decode()) ?? .empty
        ))
        
        let childNodes: [TreeNode<ViewProperties>]
        do {
            childNodes = try c.decodeIfPresent(.children) ?? []
        } catch {
            print("Unable to decode children", error)
            childNodes = []
        }
        
        childNodes.forEach { self.add(child: $0) }
    }
}

extension LayoutProperties: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case height     = "layout_height"
        case width      = "layout_width"
        case minHeight  = "min_height"
        case minWidth   = "min_width"
        case maxHeight  = "max_height"
        case maxWidth   = "max_width"
        
        case positionTop    = "layout_top"
        case positionLeft   = "layout_left"
        case positionBottom = "layout_bottom"
        case positionRight  = "layout_right"
        
        case margin         = "layout_margin"
        case marginTop      = "layout_margin_top"
        case marginBottom   = "layout_margin_bottom"
        case marginLeft     = "layout_margin_left"
        case marginRight    = "layout_margin_right"
        
        case padding        = "padding"
        case paddingTop     = "padding_top"
        case paddingBottom  = "padding_bottom"
        case paddingLeft    = "padding_left"
        case paddingRight   = "padding_right"
        
        case gravity
        
        case flexShrink     = "layout_flex_shrink"
        case flexGrow       = "layout_flex_grow"
        case flexBasis      = "layout_flex_basis"
        
        case transformScale         = "transform_scale"
        case transformTranslateX    = "transform_translate_x"
        case transformTranslateY    = "transform_translate_y"
        case transformRotate        = "transform_rotate"
        case transformOrigin        = "transform_origin"
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        let defaults = LayoutProperties.empty
        
        self.position = .init(
            top: try? c.decode(.positionTop),
            left: try? c.decode(.positionLeft),
            bottom: try? c.decode(.positionBottom),
            right: try? c.decode(.positionRight)
        )
        
        let basePadding: Unit = (try? c.decode(.padding)) ?? .pts(0)
        self.padding = UnitEdges(
            top: (try? c.decode(.paddingTop)) ?? basePadding,
            left: (try? c.decode(.paddingLeft)) ?? basePadding,
            bottom: (try? c.decode(.paddingBottom)) ?? basePadding,
            right: (try? c.decode(.paddingRight)) ?? basePadding
        )
        
        let baseMargin: Unit = (try? c.decode(.margin)) ?? .pts(0)
        self.margins = UnitEdges(
            top: (try? c.decode(.marginTop)) ?? baseMargin,
            left: (try? c.decode(.marginLeft)) ?? baseMargin,
            bottom: (try? c.decode(.marginBottom)) ?? baseMargin,
            right: (try? c.decode(.marginRight)) ?? baseMargin
        )
        
        self.size = Size(
            width: try? c.decode(.width),
            height: try? c.decode(.height)
        )
        self.minSize = Size(
            width: try? c.decode(.minWidth),
            height: try? c.decode(.minHeight)
        )
        self.maxSize = Size(
            width: try? c.decode(.maxWidth),
            height: try? c.decode(.maxHeight)
        )
        
        self.gravity = try? c.decode(.gravity)
        
        self.flexShrink = (try? c.decode(.flexShrink)) ?? defaults.flexShrink
        self.flexGrow = (try? c.decode(.flexGrow)) ?? defaults.flexGrow
        self.flexBasis = (try? c.decode(.flexBasis)) ?? defaults.flexBasis
        
        var transform = defaults.transform
        if let scale: Double = try? c.decode(.transformScale) {
            transform.scale = scale
        }
        if let translateX: Unit = try? c.decode(.transformTranslateX) {
            transform.translate.x = translateX
        }
        if let translateY: Unit = try? c.decode(.transformTranslateY) {
            transform.translate.y = translateY
        }
        if let rotateDegs: Double = try? c.decode(.transformRotate) {
            transform.rotate = rotateDegs * .pi / 180
        }
        if let originVals: [Unit] = try? c.decode(.transformOrigin),
            originVals.count > 1 {
            transform.origin = Point(x: originVals[0], y: originVals[1])
        }
        
        self.transform = transform
    }
}

extension StyleProperties: Decodable {

    enum CodingKeys: String, CodingKey {
        case role, meta, link, title
        case clipsChildren = "clip_children"
        case backgroundColor = "background_color"
        
        case cornerRadius = "corner_radius"
        case cornerRadiusTopLeft = "corner_top_left_radius"
        case cornerRadiusTopRight = "corner_top_right_radius"
        case cornerRadiusBottomLeft = "corner_bottom_left_radius"
        case cornerRadiusBottomRight = "corner_bottom_right_radius"
        
        case strokeWidth = "stroke_width"
        case strokeWidthTop = "stroke_top_width"
        case strokeWidthRight = "stroke_right_width"
        case strokeWidthLeft = "stroke_left_width"
        case strokeWidthBottom = "stroke_bottom_width"
        
        case strokeColor = "stroke_color"
        case strokeColorTop = "stroke_top_color"
        case strokeColorRight = "stroke_right_color"
        case strokeColorLeft = "stroke_left_color"
        case strokeColorBottom = "stroke_bottom_color"
        
        case strokeStyle = "stroke_style"
        
        case backgroundImage = "background_image"
        case backgroundImageTileMode = "background_tile_mode"
        case backgroundImagePosition = "background_image_position"
        case backgroundImageScaleType = "background_image_scale_type"
        
        case shadowRadius = "shadow_radius"
        case shadowOffsetX = "shadow_dx"
        case shadowOffsetY = "shadow_dy"
        case shadowColor = "shadow_color"
        
        case accessibilityHidden = "accessibility_hidden"
        case accessibilityLabel = "accessibility_label"
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        self.role = try? c.decode(.role)
        self.meta = (try? c.decode(.meta)) ?? [:]
        
        self.link = try? c.decode(.link)
        self.title = try? c.decode(.title)
        
        self.clipsChildren = (try? c.decode(.clipsChildren)) ?? true
        self.backgroundColor = try? c.decode(.backgroundColor)
        
        let baseCornerRadius: Unit = (try? c.decode(.cornerRadius)) ?? .pts(0)
        self.cornerRadius = Corners<Unit>(
            topLeft: (try? c.decode(.cornerRadiusTopLeft)) ?? baseCornerRadius,
            topRight: (try? c.decode(.cornerRadiusTopRight)) ?? baseCornerRadius,
            bottomLeft: (try? c.decode(.cornerRadiusBottomLeft)) ?? baseCornerRadius,
            bottomRight: (try? c.decode(.cornerRadiusBottomRight)) ?? baseCornerRadius
        )
        
        let baseStrokeWidth: Double = (try? c.decode(.strokeWidth)) ?? 0
        let strokeWidth = Edges<Double>(
            top: (try? c.decode(.strokeWidthTop)) ?? baseStrokeWidth,
            left: (try? c.decode(.strokeWidthLeft)) ?? baseStrokeWidth,
            bottom: (try? c.decode(.strokeWidthBottom)) ?? baseStrokeWidth,
            right: (try? c.decode(.strokeWidthRight)) ?? baseStrokeWidth
        )
        // if there is any stroke width, get the other properties
        if !(strokeWidth.isUniform && strokeWidth.top == 0) {
            let baseStrokeColor: Color = (try? c.decode(.strokeColor)) ?? Color(r: 0, g: 0, b: 0, a: 1)
            let strokeColor = Edges<Color>(
                top: (try? c.decode(.strokeColorTop)) ?? baseStrokeColor,
                left: (try? c.decode(.strokeColorLeft)) ?? baseStrokeColor,
                bottom: (try? c.decode(.strokeColorBottom)) ?? baseStrokeColor,
                right: (try? c.decode(.strokeColorRight)) ?? baseStrokeColor
            )
            
            let strokeStyle: Stroke.Style = (try? c.decode(.strokeStyle)) ?? .solid
            
            self.stroke = Stroke(
                style: strokeStyle,
                width: strokeWidth,
                color: strokeColor
            )
        }
        
        if let bgImageSrc: URL = try? c.decode(.backgroundImage) {
            var bgImage = BackgroundImage(source: bgImageSrc)
            bgImage.scale = (try? c.decode(.backgroundImageScaleType)) ?? bgImage.scale
            bgImage.position = (try? c.decode(.backgroundImagePosition)) ?? bgImage.position
            bgImage.tileMode = (try? c.decode(.backgroundImageTileMode)) ?? bgImage.tileMode
            self.backgroundImage = bgImage
        } else {
            self.backgroundImage = nil
        }
        
        let shadowColor: Color? = try? c.decode(.shadowColor)
        let shadowRadius: Double = (try? c.decode(.shadowRadius)) ?? 0
        let shadowOffset = Size<Double>(
            width: (try? c.decode(.shadowOffsetX)) ?? 0,
            height: (try? c.decode(.shadowOffsetY)) ?? 0
        )
        if shadowColor != nil || shadowRadius > 0 || shadowOffset.width > 0 || shadowOffset.height > 0 {
            self.shadow = Shadow(
                color: shadowColor ?? Color(r: 0, g: 0, b: 0, a: 1),
                offset: shadowOffset,
                radius: shadowRadius
            )
        }
        
        self.accessibility = Accessibility(
            label: try? c.decode(.accessibilityLabel),
            isHidden: (try? c.decode(.accessibilityHidden)) ?? false
        )
    }
}

extension TextViewProperties: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case text
        case allCaps        = "text_all_caps"
        case fontFamily     = "font_family"
        case textColor      = "text_color"
        case textAlignment  = "text_alignment"
        case textSize       = "text_size"
        case textStyle      = "text_style"
        case preventWidow   = "text_prevent_widow"
        case lineHeightMultiplier = "line_spacing_multiplier"
        case spans
        case maxLines       = "max_lines"

        case textShadowRadius = "text_shadow_radius"
        case textShadowOffsetX = "text_shadow_dx"
        case textShadowOffsetY = "text_shadow_dy"
        case textShadowColor = "text_shadow_color"
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        self.text = try c.decode(.text)
        self.allCaps = (try? c.decode(.allCaps)) ?? self.allCaps
        self.fontFamily = (try? c.decode(.fontFamily)) ?? self.fontFamily
        self.textColor = (try? c.decode(.textColor)) ?? self.textColor
        self.textAlignment = (try? c.decode(.textAlignment)) ?? self.textAlignment
        self.textSize = (try? c.decode(.textSize)) ?? self.textSize
        self.textStyle = (try? c.decode(.textStyle)) ?? self.textStyle
        self.preventWidow = (try? c.decode(.preventWidow)) ?? self.preventWidow
        self.lineHeightMultiplier = (try? c.decode(.lineHeightMultiplier)) ?? self.lineHeightMultiplier
        self.spans = (try? c.decode(.spans)) ?? self.spans
        self.maxLines = (try? c.decode(.maxLines)) ?? self.maxLines
        
        let shadowColor: Color? = try? c.decode(.textShadowColor)
        let shadowRadius: Double = (try? c.decode(.textShadowRadius)) ?? 0
        let shadowOffset = Size<Double>(
            width: (try? c.decode(.textShadowOffsetX)) ?? 0,
            height: (try? c.decode(.textShadowOffsetY)) ?? 0
        )
        if shadowColor != nil || shadowRadius > 0 || shadowOffset.width > 0 || shadowOffset.height > 0 {
            self.shadow = Shadow(
                color: shadowColor ?? Color(r: 0, g: 0, b: 0, a: 1),
                offset: shadowOffset,
                radius: shadowRadius
            )
        }
    }
}

extension Unit: Decodable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        
        if let num = try? c.decode(Double.self) {
            self = .pts(num)
        } else {
            let scanner = Scanner(string: try c.decode(String.self))
            
            var number: Double = 0
            if scanner.scanDouble(&number) {
                if scanner.string.contains("%") {
                    self = .percent(number / 100)
                } else {
                    self = .pts(number)
                }
            } else {
                throw(DecodingError.valueNotFound(
                    Unit.self,
                    .init(codingPath: c.codingPath, debugDescription: "Unable to find valid number in Unit string '\(scanner.string)'")
                ))
            }
        }
    }
}

extension LayoutSize: Decodable {
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        
        if let unit = try? c.decode(Unit.self) {
            self = .unit(unit)
        } else {
            let str = try c.decode(String.self)
            
            switch str {
            case "wrap_content":
                self = .wrapContent
            case "match_parent":
                self = .matchParent
            default:
                throw(DecodingError.valueNotFound(
                    LayoutSize.self,
                    .init(codingPath: c.codingPath, debugDescription: "Unable to find valid LayoutSize from '\(str)'")
                ))
            }
        }
    }
}

extension FlexBasis: Decodable where Value: Decodable {
    
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        
        if let str = try? c.decode(String.self),
            str.lowercased() == "auto" {
            self = .auto
        } else {
            self = .value(try c.decode(Value.self))
        }
    }
}

extension Color: Decodable {
    
    public init?(string: String) {
        let cleanedStrVal = string.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanedStrVal == "transparent" {
            self = Color(r: 0, g: 0, b: 0, a: 0)
            return
        }
        
        if let color = cleanedStrVal.starts(with: "rgb") ? Color.scanRGBColorStr(cleanedStrVal) : Color.scanHexColorStr(cleanedStrVal) {
            self = color
            return
        }
        
        return nil
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        
        let strVal = (try c.decode(String.self))
        
        guard let color = Color(string: strVal) else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid Color string '\(strVal)'")
        }
        
        self = color
    }
    
    private static func scanRGBColorStr(_ strVal: String) -> Color? {
        let components: [Double?] = strVal
            .lowercased()
            .replacingOccurrences(of: "rgba(", with: "")
            .replacingOccurrences(of: "rgb(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .components(separatedBy: ",")
            .map {
                var strVal: String = $0
                
                var scaleFactor = 255.0
                if strVal.contains("%") {
                    strVal = strVal.replacingOccurrences(of: "%", with: "")
                    scaleFactor = 100.0
                }
                
                strVal = strVal.trimmingCharacters(in: .whitespacesAndNewlines)
                
                guard let val = Double(strVal) else {
                    return nil
                }
                return val / scaleFactor
        }
        
        guard components.count >= 3, components[0] != nil, components[1] != nil, components[2] != nil else {
            return nil
        }
        
        var color = Color(r: 0, g: 0, b: 0, a: 1.0)
        
        color.r = (components[0] ?? 0)
        color.g = (components[1] ?? 0)
        color.b = (components[2] ?? 0)
        
        // rgba values come in with `a` as a 0-1 value
        // therefore, the code above will have scaled it by /255.
        // so here we are *255 to get it back to 0-1 scale.
        if components.count >= 4 {
            color.a = (components[3] ?? 255.0) * 255
        }
        
        return color
    }
    
    private static func scanHexColorStr(_ strVal: String) -> Color? {
        let cleanedStr = strVal
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt32 = 0
        let length = cleanedStr.count
        
        let scanner = Scanner(string: cleanedStr)
        guard scanner.scanHexInt32(&rgb) else { return nil }
        guard scanner.isAtEnd else { return nil }
        
        var color = Color(r: 0, g: 0, b: 0, a: 1.0)
        
        if length == 6 {
            color.r = Double((rgb & 0xFF0000) >> 16) / 255.0
            color.g = Double((rgb & 0x00FF00) >> 8) / 255.0
            color.b = Double(rgb & 0x0000FF) / 255.0
        } else if length == 8 {
            color.r = Double((rgb & 0xFF000000) >> 24) / 255.0
            color.g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            color.b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            color.a = Double(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }
        return color
    }
}

extension Theme: Decodable {
    enum CodingKeys: String, CodingKey {
        case textColor = "text_color"
        case lineHeightMultiplier = "line_spacing_multiplier"
        case fontFamily = "font_family"
        case bgColor = "background_color"
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        self.textDefaults = .empty
        if let textColor: Color = try c.decodeIfPresent(.textColor) {
            self.textDefaults.textColor = textColor
        }
        if let lineHeightMultiplier: Double = try c.decodeIfPresent(.lineHeightMultiplier) {
            self.textDefaults.lineHeightMultiplier = lineHeightMultiplier
        }
        if let fontFamily: FontFamily = try c.decodeIfPresent(.fontFamily) {
            self.textDefaults.fontFamily = fontFamily
        }
        
        self.bgColor = try c.decodeIfPresent(.bgColor)
    }
}

extension FontAsset: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case src, weight, style
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        let srcArr: [[String]] = try c.decodeIfPresent(.src) ?? []
        self.sources = srcArr.compactMap {
            guard $0.count == 2,
                let typeStr = $0.first,
                let type = SourceType(rawValue: typeStr),
                let urlStr = $0.last,
                let url = URL(string: urlStr) else {
                    return nil
            }
            
            return (type, url)
        }
        
        self.weight = try c.decodeIfPresent(.weight)
        
        self.style = try c.decodeIfPresent(.style) ?? .normal
    }
}

extension TextStyle: Decodable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        
        let name = (try? c.decode(String.self)) ?? ""
        
        if let type = TextStyle.init(rawValue: name) {
            self = type
        } else {
            let names = name.split(separator: "|")
            if Set(names) == Set(["bold", "italic"]) {
                self = .boldItalic
            } else {
                self = .normal
            }
        }
    }
}

extension FlexLayoutProperties: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case direction          = "layout_flex_direction"
        case itemAlignment      = "layout_flex_align_items"
        case contentJustification = "layout_flex_justify_content"
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        if let dir: Direction = try? c.decode(.direction) {
            self.direction = dir
        }
        if let itemAlign: ItemAlignment = try? c.decode(.itemAlignment) {
            self.itemAlignment = itemAlign
        }
        if let contentJustification: ContentJustification = try? c.decode(.contentJustification) {
            self.contentJustification = contentJustification
        }
    }
}

extension VideoViewProperties: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case source = "src"
        case autoplay
        case loop
        case controls
        case mime
        case videoWidth = "video_width"
        case videoHeight = "video_height"
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        self.source = try c.decode(.source)
        self.autoplay = (try? c.decode(.autoplay)) ?? self.autoplay
        self.loop = (try? c.decode(.loop)) ?? self.loop
        self.controls = (try? c.decode(.controls)) ?? self.controls
        self.mime = try? c.decode(.mime)
        
        if let w: Double = try? c.decode(.videoWidth),
            let h: Double = try? c.decode(.videoHeight) {
            self.videoSize = Size(width: w, height: h)
        }
    }
}

extension VideoEmbedViewProperties: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case source = "src"
        case videoWidth = "video_width"
        case videoHeight = "video_height"
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        self.source = try c.decode(.source)

        if let w: Double = try? c.decode(.videoWidth),
            let h: Double = try? c.decode(.videoHeight) {
            self.videoSize = Size(width: w, height: h)
        }
    }
}
