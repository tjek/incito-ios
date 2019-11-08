//
//  IncitoDocument+Decoding.swift
//  Incito-iOS
//
//  Created by Laurie Hufford on 08/11/2019.
//  Copyright © 2019 ShopGun. All rights reserved.
//

import Foundation

extension IncitoDocument {

    enum DecodingError: Error {
        case missingId
        case missingVersion
        case missingRootView
        case invalidJSON
    }

    enum JSONKeys: String {
        case id, version, theme, locale, meta
        case rootView = "root_view"
    }
    
    init(jsonData: Data) throws {
        
        guard let jsonStr = String(data: jsonData, encoding: .utf8) else {
            throw DecodingError.invalidJSON
        }
        
        let jsonObj = try JSONSerialization.jsonObject(with: jsonData, options: [])
        guard let jsonDict = jsonObj as? [String: Any] else {
            throw DecodingError.invalidJSON
        }
        
        self.json = jsonStr
        
        self.id = try jsonDict.getValueAs(JSONKeys.id, throwing: DecodingError.missingId)
        self.version = try jsonDict.getValueAs(JSONKeys.version, throwing: DecodingError.missingVersion)
        
        let rootViewDict: [String: Any] = try jsonDict.getValueAs(JSONKeys.rootView, throwing: DecodingError.missingRootView)
        self.elements = IncitoDocument.Element.allElements(in: rootViewDict)
        
        self.locale = jsonDict.getValueAs(JSONKeys.locale)
        
        var meta: [String: JSONValue] = [:]
        (jsonDict.getValue(JSONKeys.meta, as: [String: Any?].self) ?? [:])
            .forEach({
                meta[$0.key] = JSONValue($0.value)
            })
        self.meta = meta
        
        let bgColorStr = jsonDict.getValue(JSONKeys.theme, as: [String: Any].self)?["background_color"] as? String
        self.backgroundColor = bgColorStr.flatMap(UIColor.init(webString:))
    }
}

extension IncitoDocument.Element {
    
    enum JSONKeys: String {
        case id, role, meta, link, title, src
        case featureLabels = "feature_labels"
    }
    
    init?(jsonDict: [String: Any]) {
        // if there is no id, then fall back to the
        guard let id: String = jsonDict.getValueAs(JSONKeys.id) else {
            return nil
        }
        
        self.id = id
        self.role = jsonDict.getValueAs(JSONKeys.role)
        
        self.meta = {
            var meta: [String: JSONValue] = [:]
            (jsonDict.getValue(JSONKeys.meta, as: [String: Any?].self) ?? [:])
                .forEach({
                    meta[$0.key] = JSONValue($0.value)
                })
            return meta
        }()
        
        self.featureLabels = jsonDict.getValue(JSONKeys.featureLabels, as: [String].self) ?? []
        
        self.link = jsonDict.getValue(JSONKeys.link, as: String.self).flatMap(URL.init(string:))
        
        self.title = jsonDict.getValueAs(JSONKeys.title)
    }
    
    static func allElements(in elementDict: [String: Any]) -> [IncitoDocument.Element] {
        
        var foundElements: [IncitoDocument.Element] = []
        
        recurseAllElements(in: elementDict, foundElements: &foundElements)

        return foundElements
    }
    
    static func recurseAllElements(in elementDict: [String: Any], foundElements: inout [IncitoDocument.Element]) {

        if let element = IncitoDocument.Element(jsonDict: elementDict) {
            foundElements.append(element)
        }

        if let kids = elementDict["child_views"] as? [[String: Any]] {
            kids.forEach({
                recurseAllElements(in: $0, foundElements: &foundElements)
            })
        }
    }
}

// MARK: - Utils

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
    func getValueAs<K: RawRepresentable, T>(_ key: K, throwing error: Error) throws -> T where K.RawValue == Key {
        guard let v = getValue(key, as: T.self) else {
            throw error
        }
        return v
    }
}
