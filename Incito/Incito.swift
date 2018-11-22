//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

struct Incito {
    typealias Identifier = String // TODO
    var id: Identifier
    var version: String
    var rootView: IncitoViewType

    var locale: String?
    var theme: Theme?
    var meta: [String: JSONValue]
    var fontAssets: [FontFamilyName: FontAsset]
}

extension Incito: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case id, version
        case rootView = "root_view"
        case theme, locale, meta
        case fontAssets = "font_assets"
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try c.decode(.id)
        self.version = try c.decode(.version)
        self.rootView = try c.decode(.rootView)
        
        self.locale = try c.decodeIfPresent(.locale)
        self.theme = try c.decodeIfPresent(.theme)
        self.meta = try c.decodeIfPresent(.meta) ?? [:]
        self.fontAssets = try c.decodeIfPresent(.fontAssets) ?? [:]
    }
}

enum IncitoViewType {
    case absoluteLayout(properties: ViewProperties)
    case flexLayout(flex: FlexLayoutProperties, properties: ViewProperties)

    case view(properties: ViewProperties)
    case textView(text: TextViewProperties, properties: ViewProperties)
    case fragView(properties: ViewProperties)
    case imageView(image: ImageViewProperties, properties: ViewProperties)
    case videoEmbedView(src: String, properties: ViewProperties)
    case videoView(video: VideoViewProperties, properties: ViewProperties)
    
    var viewProperties: ViewProperties {
        switch self {
        case let .absoluteLayout(properties): return properties
        case let .flexLayout(_, properties): return properties
            
        case let .view(properties): return properties
        case let .textView(_, properties): return properties
        case let .fragView(properties): return properties
        case let .imageView(_, properties): return properties
        case let .videoEmbedView(_, properties): return properties
        case let .videoView(_, properties): return properties
        }
    }
}

extension IncitoViewType: Decodable {
    enum CodingKeys: CodingKey {
        case viewName
        /// This case defines all unknown payload keys.
        case properties(key: String)
        
        var stringValue: String {
            switch self {
            case .viewName: return "view_name"
            case .properties(let key): return key
            }
        }
        init?(stringValue: String) {
            if stringValue == CodingKeys.viewName.stringValue {
                self = .viewName
            } else {
                self = .properties(key: stringValue)
            }
        }
        
        var intValue: Int? { return Int(stringValue) }
        init?(intValue: Int) { self.init(stringValue: "\(intValue)") }
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        let propertiesContainer = try decoder.singleValueContainer()
        let viewProperties = try propertiesContainer.decode(ViewProperties.self)
        
        let viewName: String? = try? c.decode(.viewName)
        
        switch viewName {
        case "AbsoluteLayout"?:
            self = .absoluteLayout(properties: viewProperties)
        case "FlexLayout"?:
            let flexProperties = try propertiesContainer.decode(FlexLayoutProperties.self)
            self = .flexLayout(flex: flexProperties, properties: viewProperties)
        case "FragView"?:
            self = .fragView(properties: viewProperties)
        case "TextView"?:
            let textProperties = try propertiesContainer.decode(TextViewProperties.self)
            self = .textView(text: textProperties, properties: viewProperties)
        case "ImageView"?:
            let imageProperties = try propertiesContainer.decode(ImageViewProperties.self)
            self = .imageView(image: imageProperties, properties: viewProperties)
        case "VideoEmbedView"?:
            let src: String = try c.decode(.properties(key: "src"))
            self = .videoEmbedView(src: src, properties: viewProperties)
        case "VideoView"?:
            let videoProperties = try propertiesContainer.decode(VideoViewProperties.self)
            self = .videoView(video: videoProperties, properties: viewProperties)
        case "View"?,
             nil:
            fallthrough
        default:
            self = .view(properties: viewProperties)
        }
    }
}

struct ViewProperties {
    typealias Identifier = String // TODO
    var id: Identifier?
    var role: String?
    var meta: [String: JSONValue]
    var childViews: [IncitoViewType] = []

//    var cornerRadius: CornerRadius = .zero
//    var shadow: Shadow? = nil
//    var stroke: Stroke? = nil
//    var transform: Transform? = nil
//
    var position: Edges<Unit?>
    var padding: UnitEdges
    var margins: UnitEdges

    var height: LayoutSize?
    var width: LayoutSize?
    var minHeight: Unit?
    var minWidth: Unit?
    var maxHeight: Unit?
    var maxWidth: Unit?

    var link: String? // URI
    var title: String?
    var clipsChildren: Bool
//    var accessibility: Accessibility? = nil
    var gravity: HorizontalGravity?

    var backgroundColor: Color?
//    var backgroundImage: BackgroundImage? = nil
}

extension ViewProperties: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case id, role
        case meta
        case childViews = "child_views"
        
        case height = "layout_height"
        case width = "layout_width"
        case minHeight = "min_height"
        case minWidth = "min_width"
        case maxHeight = "max_height"
        case maxWidth = "max_width"
        
        case positionTop = "layout_top"
        case positionLeft = "layout_left"
        case positionBottom = "layout_bottom"
        case positionRight = "layout_right"
        
        case margin = "layout_margin"
        case marginTop = "layout_margin_top"
        case marginBottom = "layout_margin_bottom"
        case marginLeft = "layout_margin_left"
        case marginRight = "layout_margin_right"
        
        case padding = "padding"
        case paddingTop = "padding_top"
        case paddingBottom = "padding_bottom"
        case paddingLeft = "padding_left"
        case paddingRight = "padding_right"
        
        case link, title
        case clipsChildren = "clip_children"
        case gravity
        case backgroundColor = "background_color"
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try c.decodeIfPresent(.id)
        self.role = try c.decodeIfPresent(.role)
        self.meta = (try c.decodeIfPresent(.meta)) ?? [:]
        
        do {
            self.childViews = (try c.decodeIfPresent(.childViews)) ?? []
        } catch {
            print("Error", error)
            self.childViews = []
        }
        
        self.height = try c.decodeIfPresent(.height)
        self.width = try c.decodeIfPresent(.width)
        self.minHeight = try c.decodeIfPresent(.minHeight)
        self.minWidth = try c.decodeIfPresent(.minWidth)
        self.maxHeight = try c.decodeIfPresent(.maxHeight)
        self.maxWidth = try c.decodeIfPresent(.maxWidth)
        
        self.position = .init(
            top: try c.decodeIfPresent(.positionTop),
            left: try c.decodeIfPresent(.positionLeft),
            bottom: try c.decodeIfPresent(.positionBottom),
            right: try c.decodeIfPresent(.positionRight)
        )
        
        let baseMargin: Unit = try c.decodeIfPresent(.margin) ?? .pts(0)
        self.margins = UnitEdges(
            top: try c.decodeIfPresent(.marginTop) ?? baseMargin,
            left: try c.decodeIfPresent(.marginLeft) ?? baseMargin,
            bottom: try c.decodeIfPresent(.marginBottom) ?? baseMargin,
            right: try c.decodeIfPresent(.marginRight) ?? baseMargin
        )
        
        let basePadding: Unit = try c.decodeIfPresent(.padding) ?? .pts(0)
        self.padding = UnitEdges(
            top: try c.decodeIfPresent(.paddingTop) ?? basePadding,
            left: try c.decodeIfPresent(.paddingLeft) ?? basePadding,
            bottom: try c.decodeIfPresent(.paddingBottom) ?? basePadding,
            right: try c.decodeIfPresent(.paddingRight) ?? basePadding
        )
        
        // TODO: all the rest...
        self.link = try c.decodeIfPresent(.link)
        self.title = try c.decodeIfPresent(.title)
        
        self.clipsChildren = try c.decodeIfPresent(.clipsChildren) ?? true
        self.backgroundColor = try c.decodeIfPresent(.backgroundColor)
    }
}

struct TextViewProperties {
    
    struct Span: Decodable {
        enum SpanType: String, Decodable {
            case superscript
        }
        
        var name: SpanType
        var start: Int
        var end: Int
    }
    
    var text: String
    
    var allCaps: Bool
    var fontFamily: [FontFamilyName]
    var textColor: Color?
    var textAlignment: String? // todo: what?
    var textSize: Double?
    var fontStretch: String? // todo: what?
    var textStyle: String? // todo: what?
    var preventWidow: Bool
    var lineSpacingMultiplier: Double? // todo: string or number?
    var spans: [Span]
    var maxLines: Int
    
}

extension TextViewProperties: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case text
        case allCaps        = "text_all_caps"
        case fontFamily     = "font_family"
        case textColor      = "text_color"
        case textAlignment  = "text_alignment"
        case textSize       = "text_size"
        case fontStretch    = "font_stretch"
        case textStyle      = "text_style"
        case preventWidow   = "text_prevent_widow"
        case lineSpacingMultiplier = "line_spacing_multiplier"
        case spans
        case maxLines       = "max_lines"
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        self.text = try c.decode(.text)
        self.allCaps = try c.decodeIfPresent(.allCaps) ?? false
        self.fontFamily = try c.decodeIfPresent(.fontFamily) ?? []
        self.textColor = try c.decodeIfPresent(.textColor)
        self.textAlignment = try c.decodeIfPresent(.textAlignment)
        self.textSize = try c.decodeIfPresent(.textSize)
        self.fontStretch = try c.decodeIfPresent(.fontStretch)
        self.textStyle = try c.decodeIfPresent(.textStyle)
        self.preventWidow = try c.decodeIfPresent(.preventWidow) ?? false
        self.lineSpacingMultiplier = try c.decodeIfPresent(.lineSpacingMultiplier)
        self.spans = try c.decodeIfPresent(.spans) ?? []
        self.maxLines = try c.decodeIfPresent(.maxLines) ?? 1
    }
}

struct FlexLayoutProperties: Decodable {
    enum ItemAlignment: String, Decodable {
        case stretch
        case center
        case flexStart  = "flex-start"
        case flextEnd   = "flex-end"
        case baseline
    }
    
    enum ContentJustification: String, Decodable {
        case flexStart  = "flex-start"
        case flexEnd    = "flex-end"
        case center
        case spaceBetween   = "space-between"
        case spaceAround    = "space-around"
    }
    enum ContentAlignment: String, Decodable {
        case stretch
        case center
        case flexStart      = "flex-start"
        case flextEnd       = "flex-end"
        case spaceBetween   = "space-between"
        case spaceAround    = "space-around"
        case initial
    }
    enum Direction: String, Decodable {
        case row
        case column
    }
    
    var itemAlignment: ItemAlignment?
    var contentJustification: ContentJustification?
    var contentAlignment: ContentAlignment?
    var direction: Direction?
    var shrink: Double? // todo: what?
    var grow: Double? // todo: what?
    
    enum CodingKeys: String, CodingKey {
        case itemAlignment      = "layout_flex_align_items"
        case contentJustification = "layout_flex_justify_content"
        case contentAlignment   = "layout_flex_align_content"
        case direction          = "layout_flex_direction"
        case shrink             = "layout_flex_shrink"
        case grow               = "layout_flex_grow"
    }
}

struct ImageViewProperties: Decodable {
    var source: String // URI
    var caption: String?
    
    enum CodingKeys: String, CodingKey {
        case source = "src"
        case caption = "label"
    }
}
struct VideoViewProperties: Decodable {
    var source: String // URI
    var autoplay: Bool = false
    var loop: Bool = false
    var controls: Bool = true
    var mime: String?
}

/////////////////
// Definitions //
/////////////////

enum Unit {
    case pts(Double)
    case percent(Double)
}

extension Unit: Decodable {
    init(from decoder: Decoder) throws {
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

enum LayoutSize {
    case unit(Unit)
    case wrapContent
    case matchParent
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

struct Color {
    var hexVal: String
}
extension Color: Decodable {
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        self.hexVal = try c.decode(String.self)
    }
}

typealias FontFamilyName = String

struct Theme {
    var textColor: Color?
    var lineSpacingMultiplier: Double
    var fontFamily: [FontFamilyName]
    var bgColor: Color?
}

extension Theme: Decodable {
    enum CodingKeys: String, CodingKey {
        case textColor = "text_color"
        case lineSpacingMultiplier = "line_spacing_multiplier"
        case fontFamily = "font_family"
        case bgColor = "background_color"
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        self.textColor = try c.decodeIfPresent(.textColor)
        self.lineSpacingMultiplier = try c.decodeIfPresent(.lineSpacingMultiplier) ?? 1
        self.fontFamily = try c.decodeIfPresent(.fontFamily) ?? []
        self.bgColor = try c.decodeIfPresent(.bgColor)
    }
}

struct FontAsset: Decodable {
    enum SourceType: String {
        case woff
        case woff2
        case truetype
        case svg
        case opentype
        case embeddedOpentype = "embedded-opentype"
    }
    
    var src: [(SourceType, String)]
    var weight: String?
    var style: String?
    
    enum CodingKeys: String, CodingKey {
        case src, weight, style
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        let srcArr: [[String]] = try c.decodeIfPresent(.src) ?? []
        self.src = srcArr.compactMap {
            guard $0.count == 2,
                let typeStr = $0.first,
                let type = SourceType(rawValue: typeStr),
                let url = $0.last else {
                    return nil
            }
            
            return (type, url)
        }
        
        self.weight = try c.decodeIfPresent(.weight)
        self.style = try c.decodeIfPresent(.style)
    }
}

typealias CornerRadius = UnitCorners

struct Shadow {
    var color: Color
    var offsetX: Double
    var offsetY: Double
    var radius: Double
}
struct Stroke {
    enum Style {
        case solid
        case dotted
        case dashed
    }
    
    struct Properties {
        var width: Unit
        var color: Color
    }
    
    var top, left, bottom, right: Properties
}

struct Transform {
    var scale: Double?
    var translateX: Unit?
    var translateY: Unit?
    var rotate: Double? // -360 -> 360
    //    let origin: [String] // seems to more be an tuple of 2 Unit strings? x & y?
}


struct Edges<Value> {
    var top, left, bottom, right: Value
}

extension Edges {
    init(_ val: Value) {
        self.init(top: val, left: val, bottom: val, right: val)
    }
}

typealias UnitEdges = Edges<Unit>
extension Edges where Value == Unit {
    static let zero = UnitEdges(.pts(0))
}

struct UnitCorners {
    var topLeft, topRight, bottomLeft, bottomRight: Unit
}
extension UnitCorners {
    init(_ unit: Unit) {
        self.init(topLeft: unit, topRight: unit, bottomLeft: unit, bottomRight: unit)
    }
    
    static let zero = UnitCorners(.pts(0))
}

enum HorizontalGravity: String {
    case left   = "left_horizontal"
    case center = "center_horizontal"
    case right  = "right_horizontal"
}

struct Accessibility {
    var label: String
    var hidden: Bool
}

struct BackgroundImage {
    enum ScaleType {
        case centerCrop
        case centerInside
    }
    
    enum TileMode {
        case none
        case repeatX
        case repeatY
        case repeatXY
    }
    
    var image: String? // URI
    var scale: ScaleType = .centerCrop
    var imagePosition: String? // TODO: what?
    var tileMode: TileMode = .none
}
