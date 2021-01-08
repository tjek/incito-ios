///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

import UIKit

/**
 This type represents the abstract 'work' of loading an incito document.
 */
public struct IncitoLoader {
    public typealias Response = Result<IncitoDocument, Error>
    public typealias Callback = (Response) -> Void
    public let load: (@escaping Callback) -> Void
    
    public init(load: @escaping (@escaping Callback) -> Void) {
        self.load = load
    }
}

extension IncitoLoader {
    public func async(
        delay: TimeInterval = 0,
        on queue: DispatchQueue,
        blocksQueue: Bool = false,
        completesOn completionQueue: DispatchQueue = .main
        ) -> IncitoLoader {
        
        return IncitoLoader { cb in
            queue.asyncAfter(deadline: .now() + delay) {
                let grp: DispatchGroup? = blocksQueue ? DispatchGroup() : nil
                grp?.enter()
                
                self.load { value in
                    grp?.leave()
                    completionQueue.async {
                        cb(value)
                    }
                }
                grp?.wait()
            }
        }
    }
}
