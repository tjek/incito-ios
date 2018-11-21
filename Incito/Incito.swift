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
        
        self.id = try c.decode(Identifier.self, forKey: .id)
        self.version = try c.decode(String.self, forKey: .version)
        self.rootView = try c.decode(IncitoViewType.self, forKey: .rootView)
        
        self.locale = try c.decodeIfPresent(String.self, forKey: .locale)
        self.theme = try c.decodeIfPresent(Theme.self, forKey: .theme)
        self.meta = (try c.decodeIfPresent([String: JSONValue].self, forKey: .meta)) ?? [:]
        self.fontAssets = (try c.decodeIfPresent([FontFamilyName: FontAsset].self, forKey: .fontAssets)) ?? [:]
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
        
        let viewName = try? c.decode(String.self, forKey: .viewName)
        
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
            let src = try c.decode(String.self, forKey: .properties(key: "src"))
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
    var layout: UnitEdges?
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
        self.id = try c.decodeIfPresent(String.self, forKey: .id)
        self.role = try c.decodeIfPresent(String.self, forKey: .role)
        self.meta = (try c.decodeIfPresent([String: JSONValue].self, forKey: .meta)) ?? [:]
        
        do {
            self.childViews = (try c.decodeIfPresent([IncitoViewType].self, forKey: .childViews)) ?? []
        } catch {
            print("Error", error)
            self.childViews = []
        }
        
        self.height = try c.decodeIfPresent(LayoutSize.self, forKey: .height)
        self.width = try c.decodeIfPresent(LayoutSize.self, forKey: .width)
        self.minHeight = try c.decodeIfPresent(Unit.self, forKey: .minHeight)
        self.minWidth = try c.decodeIfPresent(Unit.self, forKey: .minWidth)
        self.maxHeight = try c.decodeIfPresent(Unit.self, forKey: .maxHeight)
        self.maxWidth = try c.decodeIfPresent(Unit.self, forKey: .maxWidth)
        
        let baseMargin = try c.decodeIfPresent(Unit.self, forKey: .margin) ?? .pts(0)
        self.margins = UnitEdges(
            top: try c.decodeIfPresent(Unit.self, forKey: .marginTop) ?? baseMargin,
            left: try c.decodeIfPresent(Unit.self, forKey: .marginLeft) ?? baseMargin,
            bottom: try c.decodeIfPresent(Unit.self, forKey: .marginBottom) ?? baseMargin,
            right: try c.decodeIfPresent(Unit.self, forKey: .marginRight) ?? baseMargin
        )
        
        let basePadding = try c.decodeIfPresent(Unit.self, forKey: .padding) ?? .pts(0)
        self.padding = UnitEdges(
            top: try c.decodeIfPresent(Unit.self, forKey: .paddingTop) ?? basePadding,
            left: try c.decodeIfPresent(Unit.self, forKey: .paddingLeft) ?? basePadding,
            bottom: try c.decodeIfPresent(Unit.self, forKey: .paddingBottom) ?? basePadding,
            right: try c.decodeIfPresent(Unit.self, forKey: .paddingRight) ?? basePadding
        )
        
        // TODO: all the rest...
        self.link = try c.decodeIfPresent(String.self, forKey: .link)
        self.title = try c.decodeIfPresent(String.self, forKey: .title)
        
        self.clipsChildren = try c.decodeIfPresent(Bool.self, forKey: .clipsChildren) ?? true
        self.backgroundColor = try c.decodeIfPresent(Color.self, forKey: .backgroundColor)
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
        
        self.text = try c.decode(String.self, forKey: .text)
        self.allCaps = (try c.decodeIfPresent(Bool.self, forKey: .allCaps)) ?? false
        self.fontFamily = (try c.decodeIfPresent([FontFamilyName].self, forKey: .fontFamily)) ?? []
        self.textColor = (try c.decodeIfPresent(Color.self, forKey: .textColor))
        self.textAlignment = (try c.decodeIfPresent(String.self, forKey: .textAlignment))
        self.textSize = (try c.decodeIfPresent(Double.self, forKey: .textSize))
        self.fontStretch = (try c.decodeIfPresent(String.self, forKey: .fontStretch))
        self.textStyle = (try c.decodeIfPresent(String.self, forKey: .textStyle))
        self.preventWidow = (try c.decodeIfPresent(Bool.self, forKey: .preventWidow)) ?? false
        self.lineSpacingMultiplier = (try c.decodeIfPresent(Double.self, forKey: .lineSpacingMultiplier))
        self.spans = (try c.decodeIfPresent([Span].self, forKey: .spans)) ?? []
        self.maxLines = (try c.decodeIfPresent(Int.self, forKey: .maxLines)) ?? 1
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
        
        self.textColor = try c.decodeIfPresent(Color.self, forKey: .textColor)
        self.lineSpacingMultiplier = (try c.decodeIfPresent(Double.self, forKey: .lineSpacingMultiplier)) ?? 1
        self.fontFamily = (try c.decodeIfPresent([FontFamilyName].self, forKey: .fontFamily)) ?? []
        self.bgColor = try c.decodeIfPresent(Color.self, forKey: .bgColor)
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
        
        let srcArr = try c.decodeIfPresent([[String]].self, forKey: .src) ?? []
        self.src = srcArr.compactMap {
            guard $0.count == 2,
                let typeStr = $0.first,
                let type = SourceType(rawValue: typeStr),
                let url = $0.last else {
                    return nil
            }
            
            return (type, url)
        }
        
        self.weight = try c.decodeIfPresent(String.self, forKey: .weight)
        self.style = try c.decodeIfPresent(String.self, forKey: .style)
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

struct UnitEdges {
    var top, left, bottom, right: Unit
}
extension UnitEdges {
    init(_ unit: Unit) {
        self.init(top: unit, left: unit, bottom: unit, right: unit)
    }
    
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
