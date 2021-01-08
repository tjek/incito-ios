///
///  Copyright (c) 2019 Tjek. All rights reserved.
///

import Foundation

enum IncitoLoaderError: Error {
    case unavailableFile(filename: String)
}

/**
 Returns a simple IncitoLoader, that will try to load the IncitoDocument from the specified `filename` in the `bundle`
 */
public func IncitoJSONFileLoader(
    filename: String,
    bundle: Bundle = .main
    ) -> IncitoLoader {
    
    return IncitoLoader { completion in
        // - open the specified file
        // - decode the json data into an IncitoDocument
        completion(Result(catching: {
            guard let fileURL = bundle.url(forResource: filename, withExtension: nil) else {
                throw IncitoLoaderError.unavailableFile(filename: filename)
            }
            
            return try Data(contentsOf: fileURL)
        }).flatMap({ jsonData in
            Result(catching: { try IncitoDocument(jsonData: jsonData) })
        }))
    }
}
