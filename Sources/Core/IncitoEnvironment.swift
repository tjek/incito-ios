//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

public struct IncitoEnvironment {
    /// A list of all the incito schema versions supported by this library.
    public static let supportedVersions: [String] = ["1.0.0"]

    /**
     This is used by the Incito renderer to download url-based images.
     
     The default implementation performs a simple URLSession request. You can replace this with your own cached image loader if you desire.
     */
    public var imageLoader: ImageLoaderProtocol = BasicImageLoader()
}

extension IncitoEnvironment {
    public static var current = IncitoEnvironment()
}

// MARK: - Image Loader

public protocol ImageLoaderProtocol {
    func imageData(forURL url: URL, completion: @escaping ((data: Data, mimeType: String?)?) -> Void)
}

/**
 A very simple ImageLoader that, when given a url, makes a data request to the shared URLSession and calls the completion handler with the response data. There is no disk cache (to come)
 */
struct BasicImageLoader: ImageLoaderProtocol {
    
    func imageData(forURL url: URL, completion: @escaping ((data: Data, mimeType: String?)?) -> Void) {
        let urlSession = URLSession.shared
        let urlReq = URLRequest(url: url, timeoutInterval: 10)
        let task = urlSession.dataTask(with: urlReq) { data, response, error in
            guard let imageData = data else {
                completion(nil)
                return
            }

            completion((imageData, response?.mimeType))
        }
        task.resume()
    }
}
