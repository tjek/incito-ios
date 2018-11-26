//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

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

extension View: Decodable {
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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        let propertiesContainer = try decoder.singleValueContainer()
        
        // Decode the type and type-specific properties
        let viewName: String? = try? c.decode(.viewName)
        switch viewName {
        case "AbsoluteLayout"?:
            self.type = .absoluteLayout
        case "FlexLayout"?:
            let flexProperties = (try? propertiesContainer.decode(FlexLayoutProperties.self)) ?? FlexLayoutProperties()
            self.type = .flexLayout(flexProperties)
        case "TextView"?:
            let textProperties = try propertiesContainer.decode(TextViewProperties.self)
            self.type = .text(textProperties)
        case "ImageView"?:
            let imageProperties = try propertiesContainer.decode(ImageViewProperties.self)
            self.type = .image(imageProperties)
        case "VideoEmbedView"?:
            let src: String = try c.decode(.properties(key: "src"))
            self.type = .videoEmbed(src: src)
        case "VideoView"?:
            let videoProperties = try propertiesContainer.decode(VideoViewProperties.self)
            self.type = .video(videoProperties)
        case "View"?,
             nil:
            fallthrough
        default:
            self.type = .view
        }
        
        self.style = (try? propertiesContainer.decode()) ?? .empty
        self.id = try c.decodeIfPresent(.id)
        self.layout = (try? propertiesContainer.decode()) ?? .empty

        do {
            self.children = try c.decodeIfPresent(.children) ?? []
        } catch {
            print("Unable to decode children", error)
            self.children = []
        }
    }
}

extension LayoutProperties: Decodable {
    
    enum CodingKeys: String, CodingKey {
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
        
        case gravity
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        self.position = .init(
            top: try c.decodeIfPresent(.positionTop),
            left: try c.decodeIfPresent(.positionLeft),
            bottom: try c.decodeIfPresent(.positionBottom),
            right: try c.decodeIfPresent(.positionRight)
        )
        
        let basePadding: Unit = try c.decodeIfPresent(.padding) ?? .pts(0)
        self.padding = UnitEdges(
            top: try c.decodeIfPresent(.paddingTop) ?? basePadding,
            left: try c.decodeIfPresent(.paddingLeft) ?? basePadding,
            bottom: try c.decodeIfPresent(.paddingBottom) ?? basePadding,
            right: try c.decodeIfPresent(.paddingRight) ?? basePadding
        )
        
        let baseMargin: Unit = try c.decodeIfPresent(.margin) ?? .pts(0)
        self.margins = UnitEdges(
            top: try c.decodeIfPresent(.marginTop) ?? baseMargin,
            left: try c.decodeIfPresent(.marginLeft) ?? baseMargin,
            bottom: try c.decodeIfPresent(.marginBottom) ?? baseMargin,
            right: try c.decodeIfPresent(.marginRight) ?? baseMargin
        )
        
        self.height = try c.decodeIfPresent(.height)
        self.width = try c.decodeIfPresent(.width)
        self.minHeight = try c.decodeIfPresent(.minHeight)
        self.minWidth = try c.decodeIfPresent(.minWidth)
        self.maxHeight = try c.decodeIfPresent(.maxHeight)
        self.maxWidth = try c.decodeIfPresent(.maxWidth)
        
        self.gravity = try c.decodeIfPresent(.gravity)
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
        // TODO: all the rest...
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        self.role = try c.decodeIfPresent(.role)
        self.meta = (try c.decodeIfPresent(.meta)) ?? [:]
        
        self.link = try c.decodeIfPresent(.link)
        self.title = try c.decodeIfPresent(.title)
        
        self.clipsChildren = try c.decodeIfPresent(.clipsChildren) ?? true
        self.backgroundColor = try c.decodeIfPresent(.backgroundColor)
        
        let baseCornerRadius: Unit = try c.decodeIfPresent(.cornerRadius) ?? .pts(0)
        self.cornerRadius = Corners<Unit>(
            topLeft: try c.decodeIfPresent(.cornerRadiusTopLeft) ?? baseCornerRadius,
            topRight: try c.decodeIfPresent(.cornerRadiusTopRight) ?? baseCornerRadius,
            bottomLeft: try c.decodeIfPresent(.cornerRadiusBottomLeft) ?? baseCornerRadius,
            bottomRight: try c.decodeIfPresent(.cornerRadiusBottomRight) ?? baseCornerRadius
        )
        
        // TODO: all the rest...
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
        self.maxLines = try c.decodeIfPresent(.maxLines) ?? 0
    }
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

extension Color: Decodable {
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        self.hexVal = try c.decode(String.self)
    }
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

extension FontAsset: Decodable {
    
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
