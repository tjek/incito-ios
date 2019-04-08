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
    
    enum JSONKeys: String {
        case id, version, theme, locale, meta
        case rootView = "root_view"
        case fontAssets = "font_assets"
    }
    
    init(jsonData: Data) throws {
        let jsonObj = try JSONSerialization.jsonObject(with: jsonData, options: [])
        guard let rootDict = jsonObj as? [String: Any] else {
            throw IncitoDecoderError.invalidJSON
        }
        try self.init(jsonDict: rootDict)
    }
    
    init(jsonDict: [String: Any]) throws {
        
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
        self.theme = jsonDict.getValue(JSONKeys.theme, as: [String: Any].self)
            .map(Theme.init(jsonDict:))
        
        self.rootView = try TreeNode<ViewProperties>(jsonDict: rootViewDict)
        
        #warning("Make me")
        // TODO:
        //        self.meta = (try? c.decode(.meta)) ?? self.meta
        //        self.fontAssets = (try? c.decode(.fontAssets)) ?? self.fontAssets
        
    }
}

// Mark: - Root Properties

extension Theme {
    
    enum JSONKeys: String {
        case bgColor = "background_color"
    }
    
    init(jsonDict: [String: Any]) {
        self.textDefaults = TextViewDefaultProperties(jsonDict: jsonDict)
        self.bgColor = jsonDict.getValueAs(JSONKeys.bgColor)
            .flatMap(Color.init(string:))
    }
}

extension TextViewDefaultProperties {
    
    enum JSONKeys: String {
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

// MARK: - View Nodes

extension TreeNode where T == ViewProperties {
    
    enum JSONKeys: String {
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
    
    enum JSONKeys: String {
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
    init(jsonDict: [String: Any]) throws {
        #warning("Make me")
        self = .view
    }
}

extension StyleProperties {
    init(jsonDict: [String: Any]) throws {
        #warning("Make me")
        self = .empty
        self.backgroundColor = Color(r: 1, g: 0, b: 0, a: 0.2)
    }
}


extension LayoutProperties {
    
    enum JSONKeys: String {
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
    
    enum JSONKeys: String {
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
