//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2019 ShopGun. All rights reserved.

import Foundation

extension Dictionary {
    func getValueMap<K: RawRepresentable, T>(_ key: K, _ transform: (Value) -> T) -> T? where K.RawValue == Key {
        return self[key.rawValue].map(transform)
    }
    func getValueFlatMap<K: RawRepresentable, T>(_ key: K, _ transform: (Value) -> T?) -> T? where K.RawValue == Key {
        return self[key.rawValue].flatMap(transform)
    }
    func getValueAs<K: RawRepresentable, T>(_ key: K) -> T? where K.RawValue == Key {
        return getValue(key, as: T.self)
    }
    func getValue<K: RawRepresentable, T>(_ key: K, as: T.Type) -> T? where K.RawValue == Key {
        return getValueFlatMap(key, { $0 as? T })
    }
}

enum IncitoDecoderError: Error {
    case invalidJSON
}

extension IncitoDocument where ViewTreeNode == ViewProperties {
    
    enum JSONKeys: String, CodingKey {
        case id, version, theme, locale, meta
        case rootView = "root_view"
        case fontAssets = "font_assets"
    }
    
    public init(jsonData: Data) throws {
        let jsonObj = try JSONSerialization.jsonObject(with: jsonData, options: [])
        guard let rootDict = jsonObj as? [String: Any] else {
            throw IncitoDecoderError.invalidJSON
        }
        try self.init(jsonDict: rootDict)
    }
    
    public init(jsonDict: [String: Any]) throws {
        
        guard
            let id: String = jsonDict.getValueAs(JSONKeys.id),
            let version: String = jsonDict.getValueAs(JSONKeys.version),
            let rootViewDict: [String: Any] = jsonDict.getValueAs(JSONKeys.rootView)
            else {
                throw IncitoDecoderError.invalidJSON
        }
        
        self.id = .init(rawValue: id)
        self.version = version
        self.locale = jsonDict.getValueAs(JSONKeys.locale)
        self.meta = (jsonDict.getValue(JSONKeys.meta, as: [String: Any?].self) ?? [:]).compactMapValues(JSONValue.init)
        self.theme = jsonDict.getValue(JSONKeys.theme, as: [String: Any].self)
            .map(Theme.init(jsonDict:))
        
        self.fontAssets = jsonDict.getValue(JSONKeys.fontAssets, as: [String: [String: Any]].self)
            .map({
                $0.compactMapValues(FontAsset.init(jsonDict:))
            }) ?? [:]
        
        self.rootView = try TreeNode<ViewProperties>(jsonDict: rootViewDict)
    }
}

// Mark: - Root Properties

extension Theme {
    
    enum JSONKeys: String, CodingKey {
        case bgColor = "background_color"
    }
    
    init(jsonDict: [String: Any]) {
        self.textDefaults = TextViewDefaultProperties(jsonDict: jsonDict)
        self.bgColor = jsonDict.getValueAs(JSONKeys.bgColor)
            .flatMap(Color.init(string:))
    }
}

extension TextViewDefaultProperties {
    
    enum JSONKeys: String, CodingKey {
        case textColor            = "text_color"
        case lineHeightMultiplier = "line_spacing_multiplier"
        case fontFamily           = "font_family"
    }
    
    init(jsonDict: [String: Any]) {
        let defaults = TextViewDefaultProperties.empty
        
        self.textColor = jsonDict.getValueAs(JSONKeys.textColor)
            .flatMap(Color.init(string:)) ?? defaults.textColor
        
        self.lineHeightMultiplier = jsonDict.getValueAs(JSONKeys.lineHeightMultiplier) ?? defaults.lineHeightMultiplier
        
        self.fontFamily = jsonDict.getValueAs(JSONKeys.fontFamily) ?? defaults.fontFamily
    }
}

extension FontAsset {
    
    enum JSONKeys: String, CodingKey {
        case src, weight, style
    }
    
    init(jsonDict: [String: Any]) {
        
        self.sources = (jsonDict.getValue(JSONKeys.src, as: [[String]].self) ?? [])
            .compactMap({
                guard $0.count == 2,
                    let typeStr = $0.first,
                    let type = SourceType(rawValue: typeStr),
                    let urlStr = $0.last,
                    let url = URL(string: urlStr) else {
                        return nil
                }
                
                return (type, url)
            })
        
        self.weight = jsonDict.getValueAs(JSONKeys.weight)
        
        self.style = jsonDict.getValueAs(JSONKeys.style).flatMap(TextStyle.init(string:)) ?? .normal
    }
}

extension TextStyle {
    init?(string: String) {
        if let type = TextStyle.init(rawValue: string) {
            self = type
        } else {
            let names = string.split(separator: "|")
            if Set(names) == Set(["bold", "italic"]) {
                self = .boldItalic
            } else {
                return nil
            }
        }
    }
}

extension JSONValue {
    init?(_ any: Any?) {
        if let dict = any as? [String: Any?] {
            self = .object(dict.compactMapValues(JSONValue.init))
        } else if let array = any as? [Any?] {
            self = .array(array.compactMap(JSONValue.init))
        } else if let string = any as? String {
            self = .string(string)
        } else if let bool = any as? Bool {
            self = .bool(bool)
        } else if let int = any as? Int {
            self = .int(int)
        } else if let number = any as? Float {
            self = .number(number)
        } else if any == nil {
            self = .null
        } else {
            return nil
        }
    }
}

// MARK: - View Nodes

extension TreeNode where T == ViewProperties {
    
    enum JSONKeys: String, CodingKey {
        case childViews = "child_views"
    }
    
    convenience init(jsonDict: [String: Any]) throws {
        
        self.init(value: try ViewProperties(jsonDict: jsonDict))
        
        if let childNodes = jsonDict.getValue(JSONKeys.childViews, as: [[String: Any]].self)?
            .compactMap({ try? TreeNode<ViewProperties>(jsonDict: $0) }) {
            self.add(children: childNodes)
        }
    }
}

extension ViewProperties {
    
    enum JSONKeys: String, CodingKey {
        case id = "id"
    }
    
    init(jsonDict: [String: Any]) throws {
        self = ViewProperties(
            id: .generate(),
            name: jsonDict.getValueAs(JSONKeys.id),
            type: try ViewType(jsonDict: jsonDict),
            style: try StyleProperties(jsonDict: jsonDict),
            layout: LayoutProperties(jsonDict: jsonDict)
        )
    }
}

extension ViewType {
    
    enum JSONKeys: String, CodingKey {
        case viewName = "view_name"
    }
    
    init(jsonDict: [String: Any]) throws {
        
        let viewName: String? = jsonDict.getValueAs(JSONKeys.viewName)
        
        switch viewName {
        case "AbsoluteLayout"?:
            self = .absoluteLayout
        case "FlexLayout"?:
            self = .flexLayout(FlexLayoutProperties(jsonDict: jsonDict))
        case "TextView"?:
            self = .text(try TextViewProperties(jsonDict: jsonDict))
        case "ImageView"?:
            self = .image(try ImageViewProperties(jsonDict: jsonDict))
        case "VideoEmbedView"?:
            self = .videoEmbed(try VideoEmbedViewProperties(jsonDict: jsonDict))
        case "VideoView"?:
            self = .video(try VideoViewProperties(jsonDict: jsonDict))
        case "View"?,
             nil:
            fallthrough
        default:
            self = .view
        }
    }
}

extension FlexLayoutProperties {
    
    enum JSONKeys: String, CodingKey {
        case direction            = "layout_flex_direction"
        case itemAlignment        = "layout_flex_align_items"
        case contentJustification = "layout_flex_justify_content"
    }
    
    init(jsonDict: [String: Any]) {
        
        self.direction = jsonDict
            .getValueAs(JSONKeys.direction)
            .flatMap(Direction.init(rawValue:))
            ?? self.direction

        self.itemAlignment = jsonDict
            .getValueAs(JSONKeys.itemAlignment)
            .flatMap(ItemAlignment.init(rawValue:))
            ?? self.itemAlignment

        self.contentJustification = jsonDict
            .getValueAs(JSONKeys.contentJustification)
            .flatMap(ContentJustification.init(rawValue:))
            ?? self.contentJustification
    }
}

extension TextViewProperties {
    
    enum JSONKeys: String, CodingKey {
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
    
    // TODO: take default values?
    init(jsonDict: [String: Any]) throws {
        guard let text: String = jsonDict.getValueAs(JSONKeys.text) else {
            throw IncitoDecoderError.invalidJSON
        }
        
        self.text = text
        
        self.allCaps = jsonDict.getValueAs(JSONKeys.allCaps) ?? self.allCaps
        self.fontFamily = jsonDict.getValueAs(JSONKeys.fontFamily) ?? self.fontFamily
        self.textColor = jsonDict
            .getValueAs(JSONKeys.textColor)
            .flatMap(Color.init(string:))
            ?? self.textColor
        self.textAlignment = jsonDict
            .getValueAs(JSONKeys.textAlignment)
            .flatMap(TextAlignment.init(rawValue:))
            ?? self.textAlignment
        self.textSize = jsonDict.getValueAs(JSONKeys.textSize) ?? self.textSize
        self.textStyle = jsonDict
            .getValueAs(JSONKeys.textStyle)
            .flatMap(TextStyle.init(string:))
            ?? self.textStyle
        self.preventWidow = jsonDict.getValueAs(JSONKeys.preventWidow) ?? self.preventWidow
        self.lineHeightMultiplier = jsonDict.getValueAs(JSONKeys.lineHeightMultiplier) ?? self.lineHeightMultiplier
        self.spans = jsonDict
            .getValue(JSONKeys.spans, as: [[String: Any]].self)
            .flatMap({ $0.compactMap(Span.init(jsonDict:)) })
            ?? self.spans
        
        self.maxLines = jsonDict.getValueAs(JSONKeys.maxLines) ?? self.maxLines
        
        self.shadow = Shadow(
            jsonDict: jsonDict,
            keys: (
                color: JSONKeys.textShadowColor.rawValue,
                radius: JSONKeys.textShadowRadius.rawValue,
                offsetX: JSONKeys.textShadowOffsetX.rawValue,
                offsetY: JSONKeys.textShadowOffsetY.rawValue
            )
        ) ?? self.shadow
    }
}

extension TextViewProperties.Span {
    
    enum JSONKeys: String, CodingKey {
        case name, start, end
    }
    
    init?(jsonDict: [String: Any]) {
        
        guard let name = jsonDict.getValueAs(JSONKeys.name).flatMap(SpanType.init(rawValue:))
            else {
                return nil
        }
        
        self.name = name
        self.start = jsonDict.getValueAs(JSONKeys.start) ?? 0
        self.end = jsonDict.getValueAs(JSONKeys.end) ?? 0
    }
}

extension Shadow {
    init?(jsonDict: [String: Any], keys: (color: String, radius: String, offsetX: String, offsetY: String)) {
       
        let color = (jsonDict[keys.color] as? String)            .flatMap(Color.init(string:))
        
        let radius = (jsonDict[keys.radius] as? Double) ?? 0
        
        let offset = Size<Double>(
            width: (jsonDict[keys.offsetX] as? Double) ?? 0,
            height: (jsonDict[keys.offsetY] as? Double) ?? 0
        )
        
        if color != nil || radius > 0 || offset.width > 0 || offset.height > 0 {
            self = Shadow(
                color: color ?? Color(r: 0, g: 0, b: 0, a: 1),
                offset: offset,
                radius: radius
            )
        } else {
            return nil
        }
    }
}

extension ImageViewProperties {
    
    enum JSONKeys: String, CodingKey {
        case source = "src"
        case caption = "label"
    }
    
    init(jsonDict: [String: Any]) throws {
        guard let source = jsonDict.getValueAs(JSONKeys.source).flatMap(URL.init(string:)) else {
            throw IncitoDecoderError.invalidJSON
        }
       
        self.source = source
        self.caption = jsonDict.getValueAs(JSONKeys.caption) ?? self.caption
    }
}

extension VideoEmbedViewProperties {
    
    enum JSONKeys: String, CodingKey {
        case source = "src"
        case videoWidth = "video_width"
        case videoHeight = "video_height"
    }
    
    init(jsonDict: [String: Any]) throws {
        guard let source = jsonDict.getValueAs(JSONKeys.source).flatMap(URL.init(string:)) else {
            throw IncitoDecoderError.invalidJSON
        }
        
        self.source = source
        
        if let w: Double = jsonDict.getValueAs(JSONKeys.videoWidth),
            let h: Double = jsonDict.getValueAs(JSONKeys.videoHeight) {
            self.videoSize = Size(width: w, height: h)
        }
    }
}

extension VideoViewProperties {
    
    enum JSONKeys: String, CodingKey {
        case source = "src"
        case autoplay
        case loop
        case controls
        case mime
        case videoWidth = "video_width"
        case videoHeight = "video_height"
    }
    
    init(jsonDict: [String: Any]) throws {
        guard let source = jsonDict.getValueAs(JSONKeys.source).flatMap(URL.init(string:)) else {
            throw IncitoDecoderError.invalidJSON
        }
        
        self.source = source
        
        self.autoplay = jsonDict.getValueAs(JSONKeys.autoplay) ?? self.autoplay
        self.loop = jsonDict.getValueAs(JSONKeys.loop) ?? self.loop
        self.controls = jsonDict.getValueAs(JSONKeys.controls) ?? self.controls
        self.mime = jsonDict.getValueAs(JSONKeys.mime) ?? self.mime
        
        if let w: Double = jsonDict.getValueAs(JSONKeys.videoWidth),
            let h: Double = jsonDict.getValueAs(JSONKeys.videoHeight) {
            self.videoSize = Size(width: w, height: h)
        }
    }
}

extension StyleProperties {
    
    enum JSONKeys: String, CodingKey {
        case role, meta, link, title
        case featureLabels = "feature_labels"
        case backgroundColor = "background_color"
        
        case cornerRadius = "corner_radius"
        case cornerRadiusTopLeft = "corner_top_left_radius"
        case cornerRadiusTopRight = "corner_top_right_radius"
        case cornerRadiusBottomLeft = "corner_bottom_left_radius"
        case cornerRadiusBottomRight = "corner_bottom_right_radius"
        
        case shadowRadius = "shadow_radius"
        case shadowOffsetX = "shadow_dx"
        case shadowOffsetY = "shadow_dy"
        case shadowColor = "shadow_color"
        
        case accessibilityHidden = "accessibility_hidden"
        case accessibilityLabel = "accessibility_label"
    }
    
    init(jsonDict: [String: Any]) throws {
        
        let defaults = StyleProperties.empty
        
        self.role = jsonDict.getValueAs(JSONKeys.role) ?? defaults.role
        self.meta = (jsonDict.getValue(JSONKeys.meta, as: [String: Any?].self) ?? [:]).compactMapValues(JSONValue.init)
        self.featureLabels = jsonDict.getValueAs(JSONKeys.featureLabels) ?? defaults.featureLabels
        
        let baseCornerRadius = jsonDict.getValueFlatMap(JSONKeys.cornerRadius, Unit.init) ?? .pts(0)
        self.cornerRadius = Corners<Unit>(
            topLeft: jsonDict.getValueFlatMap(JSONKeys.cornerRadiusTopLeft, Unit.init) ?? baseCornerRadius,
            topRight: jsonDict.getValueFlatMap(JSONKeys.cornerRadiusTopRight, Unit.init) ?? baseCornerRadius,
            bottomLeft: jsonDict.getValueFlatMap(JSONKeys.cornerRadiusBottomLeft, Unit.init) ?? baseCornerRadius,
            bottomRight: jsonDict.getValueFlatMap(JSONKeys.cornerRadiusBottomRight, Unit.init) ?? baseCornerRadius
        )
        
        self.shadow = Shadow(
            jsonDict: jsonDict,
            keys: (
                color: JSONKeys.shadowColor.rawValue,
                radius: JSONKeys.shadowRadius.rawValue,
                offsetX: JSONKeys.shadowOffsetX.rawValue,
                offsetY: JSONKeys.shadowOffsetY.rawValue
            )
        ) ?? defaults.shadow
        
        self.stroke = Stroke(jsonDict: jsonDict) ?? defaults.stroke
        
        self.link = jsonDict.getValueAs(JSONKeys.link).flatMap(URL.init(string:)) ?? defaults.link
        self.title = jsonDict.getValueAs(JSONKeys.title)
        self.accessibility = Accessibility(
            label: jsonDict.getValueAs(JSONKeys.accessibilityLabel) ?? defaults.accessibility.label,
            isHidden: jsonDict.getValueAs(JSONKeys.accessibilityHidden) ?? defaults.accessibility.isHidden
        )
        
        self.backgroundColor = jsonDict
            .getValueAs(JSONKeys.backgroundColor)
            .flatMap(Color.init(string:))
            ?? defaults.backgroundColor
        
        self.backgroundImage = BackgroundImage(jsonDict: jsonDict) ?? defaults.backgroundImage
    }
}

extension Stroke {
    
    enum JSONKeys: String, CodingKey {
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
    }
    
    init?(jsonDict: [String: Any]) {
        let baseWidth: Double = jsonDict.getValueAs(JSONKeys.strokeWidth) ?? 0
        
        let strokeWidth = Edges<Double>(
            top: jsonDict.getValueAs(JSONKeys.strokeWidthTop) ?? baseWidth,
            left: jsonDict.getValueAs(JSONKeys.strokeWidthLeft) ?? baseWidth,
            bottom: jsonDict.getValueAs(JSONKeys.strokeWidthBottom) ?? baseWidth,
            right: jsonDict.getValueAs(JSONKeys.strokeWidthRight) ?? baseWidth
        )
        
        // if there is any stroke width, get the other properties
        guard !(strokeWidth.isUniform && strokeWidth.top == 0) else {
            return nil
        }
        
        let baseColor: Color = jsonDict.getValueAs(JSONKeys.strokeColor).flatMap(Color.init(string:)) ?? Color(r: 0, g: 0, b: 0, a: 1)
        let strokeColor = Edges<Color>(
            top: jsonDict.getValueAs(JSONKeys.strokeColorTop).flatMap(Color.init(string:)) ?? baseColor,
            left: jsonDict.getValueAs(JSONKeys.strokeColorLeft).flatMap(Color.init(string:)) ?? baseColor,
            bottom: jsonDict.getValueAs(JSONKeys.strokeColorBottom).flatMap(Color.init(string:)) ?? baseColor,
            right:  jsonDict.getValueAs(JSONKeys.strokeColorRight).flatMap(Color.init(string:)) ?? baseColor
        )

        let strokeStyle = jsonDict.getValueAs(JSONKeys.strokeStyle).flatMap(Style.init(rawValue:)) ?? .solid

        self = Stroke(
            style: strokeStyle,
            width: strokeWidth,
            color: strokeColor
        )
    }
}

extension BackgroundImage {
    enum JSONKeys: String, CodingKey {
        case source = "background_image"
        case tileMode = "background_tile_mode"
        case position = "background_image_position"
        case scaleType = "background_image_scale_type"
    }
    
    init?(jsonDict: [String: Any]) {
        
        guard let source = jsonDict.getValueAs(JSONKeys.source).flatMap(URL.init(string:)) else { return nil }
        
        self.source = source
        
        self.scale = jsonDict
            .getValueAs(JSONKeys.scaleType)
            .flatMap(ScaleType.init(rawValue:))
            ?? self.scale

        self.position = jsonDict
            .getValueAs(JSONKeys.position)
            .flatMap(Position.init(rawValue:))
            ?? self.position
        
        self.tileMode = jsonDict
            .getValueAs(JSONKeys.tileMode)
            .flatMap(TileMode.init(rawValue:))
            ?? self.tileMode
    }
}

extension LayoutProperties {
    
    enum JSONKeys: String, CodingKey {
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
        case clipsChildren = "clip_children"
        
        case flexShrink     = "layout_flex_shrink"
        case flexGrow       = "layout_flex_grow"
        case flexBasis      = "layout_flex_basis"
    }
    
    init(jsonDict: [String: Any]) {
        
        let defaults = LayoutProperties.empty
        
        self.position = .init(
            top: Unit(jsonDict[JSONKeys.positionTop.rawValue]),
            left: Unit(jsonDict[JSONKeys.positionLeft.rawValue]),
            bottom: Unit(jsonDict[JSONKeys.positionBottom.rawValue]),
            right: Unit(jsonDict[JSONKeys.positionRight.rawValue])
        )
        
        let basePadding = Unit(jsonDict[JSONKeys.padding.rawValue]) ?? .pts(0)
        self.padding = UnitEdges(
            top: Unit(jsonDict[JSONKeys.paddingTop.rawValue]) ?? basePadding,
            left: Unit(jsonDict[JSONKeys.paddingLeft.rawValue]) ?? basePadding,
            bottom: Unit(jsonDict[JSONKeys.paddingBottom.rawValue]) ?? basePadding,
            right: Unit(jsonDict[JSONKeys.paddingRight.rawValue]) ?? basePadding
        )
        
        let baseMargin = Unit(jsonDict[JSONKeys.margin.rawValue]) ?? .pts(0)
        self.margins = UnitEdges(
            top: Unit(jsonDict[JSONKeys.marginTop.rawValue]) ?? baseMargin,
            left: Unit(jsonDict[JSONKeys.marginLeft.rawValue]) ?? baseMargin,
            bottom: Unit(jsonDict[JSONKeys.marginBottom.rawValue]) ?? baseMargin,
            right: Unit(jsonDict[JSONKeys.marginRight.rawValue]) ?? baseMargin
        )
        
        self.size = Size(
            width: LayoutSize(jsonDict[JSONKeys.width.rawValue]),
            height: LayoutSize(jsonDict[JSONKeys.height.rawValue])
        )
        self.minSize = Size(
            width: Unit(jsonDict[JSONKeys.minWidth.rawValue]),
            height: Unit(jsonDict[JSONKeys.minHeight.rawValue])
        )
        self.maxSize = Size(
            width: Unit(jsonDict[JSONKeys.maxWidth.rawValue]),
            height: Unit(jsonDict[JSONKeys.maxHeight.rawValue])
        )
        
        self.gravity = jsonDict.getValueAs(JSONKeys.gravity)
            .flatMap(HorizontalGravity.init(rawValue:)) ?? defaults.gravity
        
        self.clipsChildren = jsonDict.getValueAs(JSONKeys.clipsChildren) ?? defaults.clipsChildren
        
        // if we are not clipping children, that is the equivalent of setting shrink to 0
        let defaultShrink = self.clipsChildren == false ? 0 : defaults.flexShrink
        self.flexShrink = jsonDict.getValueAs(JSONKeys.flexShrink) ?? defaultShrink
        self.flexGrow = jsonDict.getValueAs(JSONKeys.flexGrow) ?? defaults.flexGrow
        self.flexBasis = jsonDict.getValueFlatMap(JSONKeys.flexBasis, FlexBasis.init) ?? defaults.flexBasis
        
        self.transform = Transform(jsonDict: jsonDict)
    }
}

extension Transform where Value == Unit {
    
    enum JSONKeys: String, CodingKey {
        case scale      = "transform_scale"
        case translateX = "transform_translate_x"
        case translateY = "transform_translate_y"
        case rotate     = "transform_rotate"
        case origin     = "transform_origin"
    }
    
    init(jsonDict: [String: Any]) {
        let defaults = Transform.identity
        
        self.scale = jsonDict.getValueAs(JSONKeys.scale) ?? defaults.scale
        
        self.translate = Point(
            x: jsonDict.getValueFlatMap(JSONKeys.translateX, Unit.init) ?? defaults.translate.x,
            y: jsonDict.getValueFlatMap(JSONKeys.translateY, Unit.init) ?? defaults.translate.y
        )
        
        self.rotate = jsonDict.getValueAs(JSONKeys.rotate)
            .map({ $0 * Double.pi / 180.0 }) ?? defaults.rotate
        
        self.origin = jsonDict.getValue(JSONKeys.origin, as: [Any].self)
            .flatMap({
                let units = $0.compactMap(Unit.init)
                return units.count > 1 ? units : nil
            })
            .map({ (units: [Unit]) in
                Point<Unit>(x: units[0], y: units[1])
            }) ?? defaults.origin
    }
}


// MARK: - Other Types

extension Unit {
    
    init?(_ any: Any?) {
        if let num = any as? Double {
            self.init(num)
        } else if let str = any as? String {
            self.init(str)
        } else {
            return nil
        }
    }
    
    init(_ double: Double) {
        self = .pts(double)
    }
    
    init?(_ string: String) {
        let scanner = Scanner(string: string)
        
        var number: Double = 0
        if scanner.scanDouble(&number) {
            if scanner.string.contains("%") {
                self = .percent(number / 100)
            } else {
                self = .pts(number)
            }
        } else {
            return nil
        }
    }
}

extension LayoutSize {
    init?(_ any: Any?) {
        if let unit = Unit(any) {
            self = .unit(unit)
        } else if let str = any as? String {
            switch str {
            case "wrap_content":
                self = .wrapContent
            case "match_parent":
                self = .matchParent
            default:
                return nil
            }
        } else {
            return nil
        }
    }
}

extension FlexBasis where Value == Unit {
    init?(_ any: Any?) {
        if let unit = Unit(any) {
            self = .value(unit)
        } else if let str = any as? String,
            str.lowercased() == "auto" {
            self = .auto
        } else {
            return nil
        }
    }
}
