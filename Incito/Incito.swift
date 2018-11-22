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
    var rootView: View

    var locale: String?
    var theme: Theme?
    var meta: [String: JSONValue]
    var fontAssets: [FontFamilyName: FontAsset]
}

struct View {
    typealias Identifier = String // TODO
    var id: Identifier?
    
    var type: ViewType
    var style: StyleProperties
    
    var layout: LayoutProperties
    var children: [View]
}

enum ViewType {
    case view
    case absoluteLayout
    case text(TextViewProperties)
    
    case flexLayout(FlexLayoutProperties)
    case frag
    case image(ImageViewProperties)
    case videoEmbed(src: String)
    case video(VideoViewProperties)
}

struct StyleProperties {
    
    var role: String?
    var meta: [String: JSONValue]
    
    //    var cornerRadius: CornerRadius = .zero
    //    var shadow: Shadow? = nil
    //    var stroke: Stroke? = nil
    //    var transform: Transform? = nil
    
    var link: String? // URI
    var title: String?
    var clipsChildren: Bool
    //    var accessibility: Accessibility? = nil
    
    var backgroundColor: Color?
    //    var backgroundImage: BackgroundImage? = nil
    
    static let empty = StyleProperties(
        role: nil,
        meta: [:],
        link: nil,
        title: nil,
        clipsChildren: true,
        backgroundColor: nil
    )
}

struct LayoutProperties {
    var position: Edges<Unit?>
    var padding: UnitEdges
    var margins: UnitEdges
    
    var height: LayoutSize?
    var width: LayoutSize?
    var minHeight: Unit?
    var minWidth: Unit?
    var maxHeight: Unit?
    var maxWidth: Unit?
    
    var gravity: HorizontalGravity?
    
    static let empty = LayoutProperties(
        position: .init(nil),
        padding: .zero,
        margins: .zero,
        height: nil,
        width: nil,
        minHeight: nil,
        minWidth: nil,
        maxHeight: nil,
        maxWidth: nil,
        gravity: nil
    )
}

// MARK: Subtype properties

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

enum LayoutSize {
    case unit(Unit)
    case wrapContent
    case matchParent
}

struct Color {
    // TODO: support rgba etc.
    var hexVal: String
}

typealias FontFamilyName = String

struct Theme {
    var textColor: Color?
    var lineSpacingMultiplier: Double
    var fontFamily: [FontFamilyName]
    var bgColor: Color?
}

struct FontAsset {
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
    static let zero = Edges(.pts(0))
}
extension Edges where Value == Double {
    static let zero = Edges(0)
}

struct Corners<Value> {
    var topLeft, topRight, bottomLeft, bottomRight: Value
}

extension Corners {
    init(_ val: Value) {
        self.init(topLeft: val, topRight: val, bottomLeft: val, bottomRight: val)
    }
}
typealias UnitCorners = Corners<Unit>

extension Corners where Value == Unit {
    static let zero = Corners(.pts(0))
}
extension Corners where Value == Double {
    static let zero = Corners(0)
}

enum HorizontalGravity: String, Decodable {
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
