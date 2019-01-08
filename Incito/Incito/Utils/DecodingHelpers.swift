//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

/// Use type inference to avoid having to be specific.
extension KeyedDecodingContainer {
    func decode<T: Decodable>(_ key: Key) throws -> T {
        return try decode(T.self, forKey: key)
    }
    
    func decodeIfPresent<T: Decodable>(_ key: Key) throws -> T? {
        return try decodeIfPresent(T.self, forKey: key)
    }
}

extension SingleValueDecodingContainer {
    func decode<T: Decodable>() throws -> T {
        return try decode(T.self)
    }
}
