//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

public enum IncitoIdentifierType {}
public typealias IncitoDocumentIdentifier = GenericIdentifier<IncitoIdentifierType>

public struct IncitoDocument<ViewTreeNode> {
    public var id: IncitoDocumentIdentifier
    public var version: String
    public var rootView: TreeNode<ViewTreeNode>

    public var locale: String? = nil
    public var theme: Theme? = nil
    public var meta: [String: JSONValue] = [:]
    public var fontAssets: [FontAssetName: FontAsset] = [:]
}

/// An incitoDocument with ViewProperties for the ViewNodes
public typealias IncitoPropertiesDocument = IncitoDocument<ViewProperties>

public struct ViewProperties {
    public typealias Identifier = GenericIdentifier<ViewProperties>
    public var id: Identifier
    
    public var name: String?
    public var type: ViewType
    public var style: StyleProperties
    
    public var layout: LayoutProperties
}

public enum ViewType {
    case view
    case absoluteLayout
    case flexLayout(FlexLayoutProperties)
    case text(TextViewProperties)
    case image(ImageViewProperties)
    case videoEmbed(VideoEmbedViewProperties)
    case video(VideoViewProperties)
}

public struct StyleProperties {
    
    public var role: String?
    public var meta: [String: JSONValue]
    public var featureLabels: [String]
    
    public var cornerRadius: Corners<Unit>
    public var shadow: Shadow? = nil
    public var stroke: Stroke? = nil
    
    public var link: URL?
    public var title: String?
    public var accessibility: Accessibility
    
    public var backgroundColor: Color?
    public var backgroundImage: BackgroundImage?
    
    static let empty = StyleProperties(
        role: nil,
        meta: [:],
        featureLabels: [],
        cornerRadius: .zero,
        shadow: nil,
        stroke: nil,
        link: nil,
        title: nil,
        accessibility: Accessibility(label: nil, isHidden: false),
        backgroundColor: nil,
        backgroundImage: nil
    )
}

enum FlexBasis<Value> {
    case auto
    case value(Value)
}

public struct LayoutProperties {
    var position: Edges<Unit?>
    var padding: UnitEdges
    var margins: UnitEdges
    
    var size: Size<LayoutSize?>
    var minSize: Size<Unit?>
    var maxSize: Size<Unit?>
    
    var gravity: HorizontalGravity?
    
    var flexShrink: Double
    var flexGrow: Double
    var flexBasis: FlexBasis<Unit>
    
    var transform: Transform<Unit>
    
    var clipsChildren: Bool

    static let empty = LayoutProperties(
        position: .init(nil),
        padding: .zero,
        margins: .zero,
        size: .init(nil),
        minSize: .init(nil),
        maxSize: .init(nil),
        gravity: nil,
        flexShrink: 1,
        flexGrow: 0,
        flexBasis: .auto,
        transform: .identity,
        clipsChildren: true
    )
}

// MARK: Subtype properties

public struct TextViewProperties {
    
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
    
    var allCaps: Bool = false
    var fontFamily: FontFamily = []
    var textColor: Color? = nil
    var textAlignment: TextAlignment? = nil
    var textSize: Double? = nil
    var textStyle: TextStyle? = nil
    var preventWidow: Bool = false
    var lineHeightMultiplier: Double? = nil
    var spans: [Span] = []
    var maxLines: Int = 0
    var shadow: Shadow? = nil
}

public struct FlexLayoutProperties {
    enum ItemAlignment: String, Decodable {
        case stretch
        case center
        case flexStart  = "flex-start"
        case flexEnd   = "flex-end"
        case baseline
    }
    
    enum ContentJustification: String, Decodable {
        case flexStart      = "flex-start"
        case flexEnd        = "flex-end"
        case center         = "center"
        case spaceBetween   = "space-between"
        case spaceAround    = "space-around"
    }
    
    enum Direction: String, Decodable {
        case row
        case column
    }
    
    var direction: Direction = .row
    var itemAlignment: ItemAlignment = .stretch
    var contentJustification: ContentJustification = .flexStart
}

public struct ImageViewProperties: Decodable {
    var source: URL
    var caption: String? = nil// TODO: apply to imageviews
    
    enum CodingKeys: String, CodingKey {
        case source = "src"
        case caption = "label"
    }
}

public struct VideoViewProperties {
    var source: URL
    var autoplay: Bool = false
    var loop: Bool = false
    var controls: Bool = true
    var mime: String? = nil
    var videoSize: Size<Double>? = nil
}

public struct VideoEmbedViewProperties {
    var source: URL
    var videoSize: Size<Double>? = nil
}

/////////////////
// Definitions //
/////////////////

public struct Theme {
    var textDefaults: TextViewDefaultProperties
    var bgColor: Color?
}

public struct TextViewDefaultProperties {
    var textColor: Color
    var lineHeightMultiplier: Double
    var fontFamily: FontFamily
    
    // Currently not provided by server
    var textSize: Double { return 16 }
}

extension TextViewDefaultProperties {
    static var empty = TextViewDefaultProperties(
        textColor: Color(r: 0, g: 0, b: 0, a: 1),
        lineHeightMultiplier: 1,
        fontFamily: []
    )
}

public struct FontAsset {
    public typealias FontSource = (SourceType, URL)
    
    public enum SourceType: String {
        case woff2
        case woff
        case truetype
        case opentype
        case svg
        case embeddedOpentype = "embedded-opentype"
    }
    
    public var sources: [FontSource]
    public var weight: String?
    public var style: TextStyle
}

public enum TextStyle: String {
    case normal
    case bold
    case italic
    case boldItalic
}

public struct Shadow {
    var color: Color
    var offset: Size<Double>
    var radius: Double
}

public struct Stroke {
    public enum Style: String, Decodable {
        case solid
        case dotted
        case dashed
    }
    
    public var style: Style = .solid
    public var width: Edges<Double>
    public var color: Edges<Color>
    
    public init(style: Style, width: Edges<Double>, color: Edges<Color>) {
        self.style = style
        self.width = width
        self.color = color
    }
}

/// `TranslateValue` is the value used by the translate point property
struct Transform<Value> {
    var scale: Double
    var rotate: Double // radians
    // if these are % values, they are relative to the views size, not the parent's size
    var translate: Point<Value>
    var origin: Point<Value>
}

extension Transform where Value == Unit {
    static var identity = Transform(
        scale: 1,
        rotate: 0,
        translate: Point(x: .pts(0), y: .pts(0)),
        origin: Point(x: .pts(0), y: .pts(0))
    )
}
extension Transform where Value: Numeric {
    static var identity: Transform {
        return Transform(
            scale: 1,
            rotate: 0,
            translate: .zero,
            origin: .zero
        )
    }
}

enum HorizontalGravity: String, RawRepresentable, Decodable {
    case left   = "left_horizontal"
    case center = "center_horizontal"
    case right  = "right_horizontal"
}

public struct Accessibility {
    public var label: String?
    public var isHidden: Bool
}

public struct BackgroundImage {
    public enum ScaleType: String, Decodable {
        case none // original size
        case centerCrop = "center_crop" // fill
        case centerInside = "center_inside" // fit
    }
    
    public enum TileMode: String, Decodable {
        case none
        case repeatX = "repeat_x"
        case repeatY = "repeat_y"
        case repeatXY = "repeat"
    }
    
    public enum Position: String, Decodable {
        case leftTop = "left_top"
        case leftCenter = "left_center"
        case leftBottom = "left_bottom"
        case centerTop = "center_top"
        case centerCenter = "center_center"
        case centerBottom = "center_bottom"
        case rightTop = "right_top"
        case rightCenter = "right_center"
        case rightBottom = "right_bottom"
    }
    
    public var source: URL
    public var scale: ScaleType = .none
    public var position: Position = .leftTop
    public var tileMode: TileMode = .none
    
    init(source: URL) {
        self.source = source
    }
}
