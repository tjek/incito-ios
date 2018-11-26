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
    var fontAssets: [FontAssetName: FontAsset]
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
    case image(ImageViewProperties)
    case videoEmbed(src: String)
    case video(VideoViewProperties)
}

struct StyleProperties {
    
    var role: String?
    var meta: [String: JSONValue]
    
    var cornerRadius: Corners<Unit>
    //    var shadow: Shadow? = nil
    //    var stroke: Stroke? = nil
    //    var transform: Transform? = nil
    
    var link: String? // URI
    var title: String?
    var clipsChildren: Bool
    //    var accessibility: Accessibility? = nil
    
    var backgroundColor: Color?
    var backgroundImage: BackgroundImage?
    
    static let empty = StyleProperties(
        role: nil,
        meta: [:],
        cornerRadius: .zero,
        link: nil,
        title: nil,
        clipsChildren: true,
        backgroundColor: nil,
        backgroundImage: nil
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
    
    enum TextAlignment: String, Decodable {
        case left
        case right
        case center
    }
    
    var text: String
    
    var allCaps: Bool
    var fontFamily: FontFamily
    var textColor: Color?
    var textAlignment: TextAlignment?
    var textSize: Double?
    var fontStretch: String? // todo: what?
    var textStyle: TextStyle?
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
    var source: URL // URI
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

typealias FontAssetName = String
typealias FontFamily = [FontAssetName]

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

struct Theme {
    var textDefaults: TextViewDefaultProperties
    var bgColor: Color?
}

struct TextViewDefaultProperties {
    var textColor: Color
    var lineSpacingMultiplier: Double
    var fontFamily: FontFamily
    
    // Currently not provided by server
    var textSize: Double { return 16 }
}

extension TextViewDefaultProperties {
    static var empty = TextViewDefaultProperties(
        textColor: Color(hexVal: "#000000"),
        lineSpacingMultiplier: 1,
        fontFamily: []
    )
}

struct FontAsset {
    typealias FontSource = (SourceType, URL)
    
    enum SourceType: String {
        case woff2
        case woff
        case truetype
        case opentype
        case svg
        case embeddedOpentype = "embedded-opentype"
    }
    
    var sources: [FontSource]
    var weight: String?
    var style: TextStyle
}

enum TextStyle: String {
    case normal
    case bold
    case italic
    case boldItalic
}

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

extension Edges: Equatable where Value: Equatable {
    static func == (lhs: Edges<Value>, rhs: Edges<Value>) -> Bool {
        return lhs.top == rhs.top
            && lhs.left == rhs.left
            && lhs.bottom == rhs.bottom
            && lhs.right == rhs.right
    }
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

extension Corners: Equatable where Value: Equatable {
    static func == (lhs: Corners<Value>, rhs: Corners<Value>) -> Bool {
        return lhs.topLeft == rhs.topLeft
            && lhs.topRight == rhs.topRight
            && lhs.bottomLeft == rhs.bottomLeft
            && lhs.bottomRight == rhs.bottomRight
    }
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
    enum ScaleType: String, Decodable {
        case centerCrop = "center_crop"
        case centerInside = "center_inside"
    }
    
    enum TileMode: String, Decodable {
        case none
        case repeatX = "repeat_x"
        case repeatY = "repeat_y"
        case repeatXY = "repeat"
    }
    
    var source: URL
    var scale: ScaleType
    var position: String? // TODO: what? "center_center" /
    var tileMode: TileMode
}
