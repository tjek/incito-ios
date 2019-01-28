//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

public enum MeasureTimeScale {
    case seconds
    case milliseconds
    case microseconds
    case nanoseconds
    
    public var scaleFactor: Double {
        switch self {
        case .seconds:
            return 1
        case .milliseconds:
            return 1_000
        case .microseconds:
            return 1_000_000
        case .nanoseconds:
            return 1_000_000_000
        }
    }
    public var shortName: String {
        
        switch self {
        case .seconds:
            return "s"
        case .milliseconds:
            return "ms"
        case .microseconds:
            return "μs"
        case .nanoseconds:
            return "ns"
        }
    }
}

@_transparent @discardableResult public func measure(_ label: String? = nil, timeScale: MeasureTimeScale = .seconds, tests: Int, setup: @escaping () -> Void = { return }, _ block: @escaping () -> Void) -> Double {
    
    guard tests > 0 else { fatalError("Number of tests must be greater than 0") }
    
    var avgExecutionTime : CFAbsoluteTime = 0
    for _ in 1...tests {
        setup()
        let start = CFAbsoluteTimeGetCurrent()
        block()
        let end = CFAbsoluteTimeGetCurrent()
        avgExecutionTime += end - start
    }
    
    avgExecutionTime /= CFAbsoluteTime(tests)
    avgExecutionTime *= timeScale.scaleFactor
    
    if let label = label {
        let avgTimeStr = "\(avgExecutionTime)".replacingOccurrences(of: "e|E", with: " × 10^", options: .regularExpression, range: nil)
        // "Rebuilding (x2): 0.015s
        var str = label
        if tests > 1 {
            str += " (x\(tests))"
        }
        str += ": \(avgTimeStr)\(timeScale.shortName)"
        
        print(str)
    }
    
    return avgExecutionTime
}

@_transparent @discardableResult public func measure<A>(_ label: String? = nil, timeScale: MeasureTimeScale = .seconds, _ block: @escaping () -> A) -> (result: A, duration: Double) {
    
    let start = CFAbsoluteTimeGetCurrent()
    let res = block()
    let end = CFAbsoluteTimeGetCurrent()
    
    let avgExecutionTime = (end - start) * timeScale.scaleFactor
    
    if let label = label {
        let avgTimeStr = "\(avgExecutionTime)".replacingOccurrences(of: "e|E", with: " × 10^", options: .regularExpression, range: nil)
        // "Rebuilding (x2): 0.015s
        var str = label
        str += ": \(avgTimeStr)\(timeScale.shortName)"
        
        print(str)
    }
    
    return (res, avgExecutionTime)
}
