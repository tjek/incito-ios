//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

public enum JSONValue: Equatable {
    case string(String)
    case int(Int)
    case number(Float)
    case object([String: JSONValue])
    case array([JSONValue])
    case bool(Bool)
    case null
}

extension JSONValue {
    
    public var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }
    public var intValue: Int? {
        guard case .int(let value) = self else { return nil }
        return value
    }
    public var numberValue: Float? {
        guard case .number(let value) = self else { return nil }
        return value
    }
    public var objectValue: [String: JSONValue]? {
        guard case .object(let value) = self else { return nil }
        return value
    }
    public var arrayValue: [JSONValue]? {
        guard case .array(let value) = self else { return nil }
        return value
    }
    public var boolValue: Bool? {
        guard case .bool(let value) = self else { return nil }
        return value
    }
    public var isNullValue: Bool {
        guard case .null = self else { return false }
        return true
    }
}

extension JSONValue: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case let .array(array):
            try container.encode(array)
        case let .object(object):
            try container.encode(object)
        case let .string(string):
            try container.encode(string)
        case let .int(int):
            try container.encode(int)
        case let .number(number):
            try container.encode(number)
        case let .bool(bool):
            try container.encode(bool)
        case .null:
            try container.encodeNil()
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let number = try? container.decode(Float.self) {
            self = .number(number)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Invalid JSON value.")
            )
        }
    }
}

extension JSONValue {
    /**
     Try to create a JSONValue from an optional Any type.
     */
    public init?(_ any: Any?) {
        if let dict = any as? [String: Any?] {
            var values: [String: JSONValue] = [:]
            dict.forEach({
                values[$0.key] = JSONValue($0.value)
            })
            self = .object(values)
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

extension JSONValue: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        switch self {
        case .string(let str):
            return str.debugDescription
        case .number(let num):
            return num.debugDescription
        case .int(let int):
            return int.description
        case .bool(let bool):
            return bool.description
        case .null:
            return "null"
        default:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            return (try? String(data: encoder.encode(self), encoding: .utf8)!) ?? "<Invalid JSON>"
        }
    }
}
