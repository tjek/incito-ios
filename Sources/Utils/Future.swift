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
    typealias Callback = (A) -> Void
    let _run: (@escaping Callback) -> Void
    
    init(run: @escaping (@escaping Callback) -> Void) {
        self._run = run
    }
    
    func run(_ completion: @escaping Callback) {
        _run(completion)
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
    
    public func zipWith<B, C>(_ other: Future<B>, _ combine: @escaping (A,B) -> C) -> Future<C> {
        return Future<C> { callbackC in
            let group = DispatchGroup()
            var resultA: A!
            var resultB: B!
            group.enter()
            self.run { resultA = $0; group.leave() }
            group.enter()
            other.run { resultB = $0; group.leave() }
            
            group.notify(queue: .global(), execute: {
                callbackC(combine(resultA, resultB))
            })
        }
    }
    
    public func zip<B>(_ other: Future<B>) -> Future<(A, B)> {
        return zipWith(other) { ($0, $1) }
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

//extension Future {
//    init(_ work: @autoclosure @escaping () -> A) {
//        self = Future { callback in
//            DispatchQueue.global().async {
//                callback(work())
//            }
//        }
//    }
//}

/////////////////////////


//func zip<A, B, E>(
//    _ lhs: Parallel<Result<A, E>>,
//    _ rhs: Parallel<Result<B, E>>
//    ) -> Parallel<Result<(A, B), E>> {
//
//    return zip(with: zip)(lhs, rhs)
//
//    //  return zip(lhs, rhs).map { resultA, resultB in
//    //    zip(resultA, resultB)
//    //  }
//}
//
//func flatMap<A, B>(
//    _ f: @escaping (A) -> Future<Result<B>>
//    ) -> (Future<Result<A>>) -> Future<Result<B>> {
//
//    return { futureResultA in
//        futureResultA.flatMap { resultA in
//            Future<Result<B>> { callback in
//                switch resultA {
//                case let .success(a):
//                    f(a).run { resultB in callback(resultB) }
//                case let .error(error):
//                    callback(.error(error))
//                }
//            }
//        }
//    }
//}

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
    
    func flatMap<S, T>(
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
    
//    public func flatMapResult<T, B>(_ transform: @escaping (T) -> Future<Result<B>>) -> Future<Result<B>> where A == Result<T> {
//        return Future<Result<B>> { callbackB in
//            self.run { resultT in
//                switch resultT {
//                case let .success(valueT):
//                    transform(valueT).run(callbackB)
//                case let .error(error):
//                    callbackB(.error(error))
//                }
//            }
//        }
//    }

    public func zip<S, T>(
        _ other: Future<Result<T>>
        ) -> Future<Result<(S, T)>> where A == Result<S> {
        return self.zipWith(other) { $0.zip($1) }
    }
    
//    public func zipWith<S, T>(
//        _ other: Future<Result<T>>
//        
//        ) -> Future<Result<(S, T)>> where A == Result<S> {
//        return self.zipWith(other) { $0.zip($1) }
//    }
    
    public func zipResultWith<T, B, C>(_ other: Future<Result<B>>, _ combine: @escaping (Result<T>, Result<B>) -> Result<C>) -> Future<Result<C>> where A == Result<T> {
        return Future<Result<C>> { callbackC in
            let group = DispatchGroup()
            var resultA: Result<T>!
            var resultB: Result<B>!
            group.enter()
            self.run { resultA = $0; group.leave() }
            group.enter()
            other.run { resultB = $0; group.leave() }

            group.notify(queue: .global(), execute: {
                callbackC(combine(resultA, resultB))
            })
        }
    }
    
    public func zipResultValueWith<T, B, C>(_ other: Future<Result<B>>, _ combine: @escaping (T, B) -> C) -> Future<Result<C>> where A == Result<T> {
        return self.zipWith(other) { $0.zipWith($1, combine) }
    }
}


