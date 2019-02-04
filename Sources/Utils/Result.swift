//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

public enum Result<A> {
    case success(A)
    case error(Error)
}

extension Result {
    public init(_ value: A?, or error: Error) {
        if let value = value {
            self = .success(value)
        } else {
            self = .error(error)
        }
    }

    public var value: A? {
        guard case .success(let v) = self else { return nil }
        return v
    }

    public var error: Error? {
        guard case .error(let e) = self else { return nil }
        return e
    }
}

extension Result {
    public init(catching f: () throws -> A) {
        do {
            self = .success(try f())
        } catch {
            self = .error(error)
        }
    }
}

extension Result {
    public func map<B>(_ transform: @escaping (A) -> B) -> Result<B> {
        switch self {
        case let .success(a):
            return .success(transform(a))
        case let .error(e):
            return .error(e)
        }
    }
    
    public func flatMap<B>(_ transform: @escaping (A) -> Result<B>) -> Result<B> {
        switch self {
        case let .success(a):
            return transform(a)
        case let .error(e):
            return .error(e)
        }
    }
    
    public func zip<B>(_ other: Result<B>) -> Result<(A, B)> {
        switch (self, other) {
        case let (.success(a), .success(b)):
            return .success((a, b))
        case let (.error(error), _):
            return .error(error)
        case let (.success, .error(error)):
            return .error(error)
        }
    }
    
    public func zipWith<B, C>(_ other: Result<B>, _ combine: @escaping (A, B) -> C) -> Result<C> {
        return self.zip(other).map(combine)
    }
}
