//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

public struct Future<Response> {
    public typealias Callback = (Response) -> Void
    let run: (@escaping Callback) -> Void
    
    public init(run: @escaping (@escaping Callback) -> Void) {
        self.run = run
    }
}

extension Future {
    public init(value: Response) {
        self.init(run: { $0(value) })
    }
    
    public init(work: @escaping () -> Response) {
        self.init(run: { $0(work()) })
    }
}

extension Future {
    
    public func map<NewResponse>(
        _ transform: @escaping (Response) -> NewResponse
        ) -> Future<NewResponse> {
        
        return Future<NewResponse> { callback in
            self.run {
                callback(transform($0))
            }
        }
    }
    
    public func flatMap<NewResponse>(
        _ transform: @escaping (Response) -> Future<NewResponse>
        ) -> Future<NewResponse> {
        
        return Future<NewResponse> { callback in
            self.run {
                transform($0).run(callback)
            }
        }
    }
    
    public func zip<OtherResponse>(
        _ other: Future<OtherResponse>
        ) -> Future<(Response, OtherResponse)> {
        
        return Future<(Response, OtherResponse)> { callback in
            let group = DispatchGroup()
            var response: Response!
            var otherResponse: OtherResponse!
            group.enter()
            self.run { response = $0; group.leave() }
            group.enter()
            other.run { otherResponse = $0; group.leave() }
            
            group.notify(queue: .global(), execute: {
                callback((response, otherResponse))
            })
        }
    }
    
    public func zipWith<OtherResponse, FinalResponse>(
        _ other: Future<OtherResponse>,
        _ combine: @escaping (Response, OtherResponse) -> FinalResponse
        ) -> Future<FinalResponse> {
        
        return self.zip(other).map(combine)
    }
    
    public func observe(
        _ callback: @escaping (Response) -> Void
        ) -> Future {
        
        return self.map {
            callback($0)
            return $0
        }
    }
}

extension Future {
    
    public func asyncOnMain() -> Future {
        return self.async(on: .main, completesOn: .main)
    }
    
    public func async(
        on queue: DispatchQueue,
        completesOn completionQueue: DispatchQueue = .main
        ) -> Future {
        
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

public typealias FutureResult<Value> = Future<Swift.Result<Value, Error>>

extension Future {
    
    public func mapResult<Success, NewSuccess, Failure>(
        _ transform: @escaping (Success) -> NewSuccess
        ) -> Future<Result<NewSuccess, Failure>>
        where Response == Result<Success, Failure> {
            
            return self.map { $0.map(transform) }
    }
    
    public func mapResultError<Success, Failure, NewFailure>(
        _ transform: @escaping (Failure) -> NewFailure
        ) -> Future<Result<Success, NewFailure>>
        where Response == Result<Success, Failure> {
            
            return self.map { $0.mapError(transform) }
    }
    
    public func flatMapResult<Success, NewSuccess, Failure>(
        _ transform: @escaping (Success) -> Future<Result<NewSuccess, Failure>>
        ) -> Future<Result<NewSuccess, Failure>>
        where Response == Result<Success, Failure> {
            
            return self.flatMap({ result in
                Future<Result<NewSuccess, Failure>> { callback in
                    switch result {
                    case let .success(s):
                        transform(s).run { callback($0) }
                    case let .failure(error):
                        callback(.failure(error))
                    }
                }
            })
    }
    
    public func flatMapResultError<Success, Failure, NewFailure>(
        _ transform: @escaping (Failure) -> Future<Result<Success, NewFailure>>
        ) -> Future<Result<Success, NewFailure>>
        where Response == Result<Success, Failure> {
            
            return self.flatMap({ result in
                Future<Result<Success, NewFailure>> { callback in
                    switch result {
                    case let .success(s):
                        callback(.success(s))
                    case let .failure(error):
                        transform(error).run { callback($0) }
                    }
                }
            })
    }


    public func zip<Success, OtherSuccess, Failure>(
        _ other: Future<Result<OtherSuccess, Failure>>
        ) -> Future<Result<(Success, OtherSuccess), Failure>>
        where Response == Result<Success, Failure> {
            
            return self.zipWith(other) { $0.zip($1) }
    }
    
    public func zipWith<Success, OtherSuccess, FinalSuccess, Failure>(
        _ other: Future<Result<OtherSuccess, Failure>>,
        _ combine: @escaping (Success, OtherSuccess) -> FinalSuccess
        ) -> Future<Result<FinalSuccess, Failure>>
        where Response == Result<Success, Failure> {
            
            return self.zipWith(other) { $0.zipWith($1, combine) }
    }
    
    public func observeResultSuccess<Success, Failure>(
        _ callback: @escaping (Success) -> Void
        ) -> Future
        where Response == Result<Success, Failure> {
            
            return self.mapResult {
                callback($0)
                return $0
            }
    }
    
    public func observeResultError<Success, Failure>(
        _ callback: @escaping (Failure) -> Void
        ) -> Future
        where Response == Result<Success, Failure> {
            
            return self.mapResultError {
                callback($0)
                return $0
            }
    }
}

// Future + Optional extensions

extension Future {
    
    public func mapOptional<Value, NewValue>(
        _ transform: @escaping (Value) -> NewValue
        ) -> Future<Optional<NewValue>>
        where Response == Optional<Value> {
            
            return self.map { $0.map(transform) }
    }
    
    public func flatMapOptional<Value, NewValue>(
        _ transform: @escaping (Value) -> Future<Optional<NewValue>>
        ) -> Future<Optional<NewValue>>
        where Response == Optional<Value> {
            
            return self.flatMap({ optional in
                Future<Optional<NewValue>> { callback in
                    if let value = optional {
                        transform(value).run(callback)
                    } else {
                        callback(nil)
                    }
                }
            })
    }
    
    public func flatMapOptionalNone<Value>(
        _ transform: @escaping () -> Future<Optional<Value>>
        ) -> Future<Optional<Value>>
        where Response == Optional<Value> {
            
            return self.flatMap({ optional in
                Future<Optional<Value>> { callback in
                    if let value = optional {
                        callback(value)
                    } else {
                        transform().run(callback)
                    }
                }
            })
    }
    
    public func zip<Value, OtherValue>(
        _ other: Future<Optional<OtherValue>>
        ) -> Future<Optional<(Value, OtherValue)>>
        where Response == Optional<Value> {
            
            return self.zipWith(other) { ($0, $1) }
    }
    
    public func zipWith<Value, OtherValue, FinalValue>(
        _ other: Future<Optional<OtherValue>>,
        _ combine: @escaping (Value, OtherValue) -> FinalValue
        ) -> Future<Optional<FinalValue>>
        where Response == Optional<Value> {
            
            return self.zipWith(other) { (a: Value?, b: OtherValue?) -> FinalValue? in
                switch (a, b) {
                case let (value?, otherValue?):
                    return combine(value, otherValue)
                default:
                    return nil
                }
            }
    }
    
    public func observeOptionalSome<Value>(
        _ callback: @escaping (Value) -> Void
        ) -> Future
        where Response == Optional<Value> {
            
            return self.mapOptional {
                callback($0)
                return $0
            }
    }
}
