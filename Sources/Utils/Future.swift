//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

public struct Future<A> {
    public typealias Callback = (A) -> Void
    let run: (@escaping Callback) -> Void
    
    public init(run: @escaping (@escaping Callback) -> Void) {
        self.run = run
    }
}

extension Future {
    init(value: A) {
        self.init(run: { $0(value) })
    }
}

extension Future {
    
    public func map<B>(_ transform: @escaping (A) -> B) -> Future<B> {
        return Future<B> { callbackB in
            self.run { valueA in
                callbackB(transform(valueA))
            }
        }
    }
    
    public func flatMap<B>(_ transform: @escaping (A) -> Future<B>) -> Future<B> {
        return Future<B> { callbackB in
            self.run { valueA in
                transform(valueA).run(callbackB)
            }
        }
    }
    
    public func zip<B>(_ other: Future<B>) -> Future<(A, B)> {
        return Future<(A, B)> { callback in
            let group = DispatchGroup()
            var resultA: A!
            var resultB: B!
            group.enter()
            self.run { resultA = $0; group.leave() }
            group.enter()
            other.run { resultB = $0; group.leave() }
            
            group.notify(queue: .global(), execute: {
                callback((resultA, resultB))
            })
        }
    }
    
    public func zipWith<B, C>(_ other: Future<B>, _ combine: @escaping (A, B) -> C) -> Future<C> {
        return self.zip(other).map(combine)
    }
    
    public func observe(_ callback: @escaping (A) -> Void) -> Future<A> {
        return Future { cb in
            self.run { a in
                callback(a)
                cb(a)
            }
        }
    }
}

extension Future {
    func async(on queue: DispatchQueue, completesOn completionQueue: DispatchQueue = .main) -> Future<A> {
        return Future { cb in
            queue.async {
                self.run { value in
                    completionQueue.async {
                        cb(value)
                    }
                }
            }
        }
    }
}

// Future + Result extensions

extension Future {
    
    public func map<S, T>(
        _ transform: @escaping (S) -> T
        ) -> Future<Result<T>> where A == Result<S> {
        return self.map { resultS in
            resultS.map { s in
                transform(s)
            }
        }
    }
    
    public func flatMap<S, T>(
        _ transform: @escaping (S) -> Future<Result<T>>
        ) -> Future<Result<T>> where A == Result<S> {
        return self.flatMap { (resultS: Result<S>) in
            Future<Result<T>> { callback in
                switch resultS {
                case let .success(s):
                    transform(s).run { resultT in callback(resultT) }
                case let .error(error):
                    callback(.error(error))
                }
            }
        }
    }

    public func zip<S, T>(
        _ other: Future<Result<T>>
        ) -> Future<Result<(S, T)>> where A == Result<S> {
        return self.zipWith(other) { $0.zip($1) }
    }
    
    public func zipWith<S, T, U>(
        _ other: Future<Result<T>>,
        _ combine: @escaping (S, T) -> U
        ) -> Future<Result<U>> where A == Result<S> {
        return self.zipWith(other) { $0.zipWith($1, combine) }
    }

    public func compactMap<S, T>(
        _ transform: @escaping (S) -> Result<T>
        ) -> Future<Result<T>> where A == Result<S> {
        return Future<Result<T>> { cb in
            self.run { s in
                cb(s.flatMap(transform))
            }
        }
    }
    
    public func onError<S>(_ other: Future<A>) -> Future<A> where A == Result<S> {
        return Future { cb in
            self.run { a in
                switch a {
                case .success:
                    cb(a)
                case .error:
                    other.run(cb)
                }
            }
            
        }
    }    
}

// Future + Optional extensions

extension Future {
    
    public func map<S, T>(
        _ transform: @escaping (S) -> T
        ) -> Future<T?> where A == S? {
        return self.map { (optionalS: A) in
            optionalS.map { s in
                transform(s)
            }
        }
    }
    
    public func flatMap<S, T>(
        _ transform: @escaping (S) -> Future<T?>
        ) -> Future<T?> where A == S? {
        return self.flatMap { (optionalS: A) in
            Future<T?> { callback in
                if let s = optionalS {
                    transform(s).run { optionalT in callback(optionalT) }
                } else {
                    callback(nil)
                }
            }
        }
    }
    
    public func zip<S, T>(
        _ other: Future<T?>
        ) -> Future<(S, T)?> where A == S? {
        return self.zipWith(other) { ($0, $1) }
    }
    
    public func zipWith<S, T, U>(
        _ other: Future<T?>,
        _ combine: @escaping (S, T) -> U
        ) -> Future<U?> where A == S? {
        return self.zipWith(other) { (opS: S?, opT: T?) -> U? in
            switch (opS, opT) {
            case let (s?, t?):
                return combine(s, t)
            default:
                return nil
            }
        }
    }
    
    public func compactMap<S, T>(
        _ transform: @escaping (S) -> T?
        ) -> Future<T?> where A == S? {
        return Future<T?> { cb in
            self.run { s in
                cb(s.flatMap(transform))
            }
        }
    }
    
    public func onNil<S>(_ other: Future<A>) -> Future<A> where A == S? {
        return Future { cb in
            self.run { a in
                if a == nil {
                    other.run(cb)
                } else {
                    cb(a)
                }
            }
            
        }
    }
}
