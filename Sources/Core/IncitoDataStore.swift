//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation
import Cache

public class IncitoDataStore {
    public static let shared = IncitoDataStore()
    
    /// Removes all Images and Fonts from the disk & memory cache
    public func clearCache() {
        try? dataStorage.removeAll()
    }
    
    fileprivate struct ImageStorageType: Codable {
        var data: Data
        var mimeType: String?
    }
    fileprivate struct FontStorageType: Codable {
        var data: Data
    }
    
    fileprivate var queue = DispatchQueue(label: "IncitoDataStore", qos: .userInitiated)
    
    fileprivate let dataStorage = try! Storage(
        diskConfig: DiskConfig(name: "Incito", maxSize: 1024*1024*100), //100Mb
        memoryConfig: MemoryConfig(),
        transformer: TransformerFactory.forData()
    )
    
    fileprivate lazy var imageStorage: Storage<ImageStorageType>  = {
        return self.dataStorage.transformCodable(ofType: ImageStorageType.self)
    }()
    
    fileprivate lazy var fontStorage: Storage<FontStorageType> = {
        return self.dataStorage.transformCodable(ofType: FontStorageType.self)
    }()
}

extension AsyncStorage {
    func object(forKey key: String) -> Future<Result<T>> {
        return Future<Result<T>> { cb in
            self.object(forKey: key) { res in
                switch res {
                case let .value(t):
                    cb(.success(t))
                case let .error(err):
                    cb(.error(err))
                }
            }
        }
    }
}

enum IncitoError: Error {
    case unknownImageRequestError
    case unknownFontRequestError
    case unableToRenderSVG
}

extension URLSession {
    
    fileprivate func imageRequest(url: URL) -> Future<Result<IncitoDataStore.ImageStorageType>> {
        return Future { completion in
            let urlReq = URLRequest(url: url, timeoutInterval: 10)
            let task = self.dataTask(with: urlReq) { data, response, error in
                
                guard let imageData = data else {
                    completion(.error(error ?? IncitoError.unknownImageRequestError))
                    return
                }
                
                completion(.success(.init(data: imageData, mimeType: response?.mimeType)))
            }
            task.resume()
        }
    }
    
    fileprivate func fontRequest(url: URL) -> Future<Result<IncitoDataStore.FontStorageType>> {
        return Future { completion in
            let urlReq = URLRequest(url: url, timeoutInterval: 10)
            let task = self.dataTask(with: urlReq) { data, response, error in
                
                guard let fontData = data else {
                    completion(.error(error ?? IncitoError.unknownFontRequestError))
                    return
                }
                
                completion(.success(.init(data: fontData)))
            }
            task.resume()
        }
    }
}

fileprivate func svgCacheKey(url: URL, containerSize: Size<Double>) -> String {
    return "\(containerSize.width)x\(containerSize.height):\(url.absoluteString)"
}

fileprivate func imageLoadResponseTransform(_ image: IncitoDataStore.ImageStorageType, url: URL, containerSize: Size<Double>) -> Result<(image: IncitoDataStore.ImageStorageType, cacheKey: String)> {
    
    switch image.mimeType {
    case "image/svg+xml"?:
        if let svgImage = SharedHTMLImageRenderer.renderSVG(image.data, containerSize: containerSize, baseURL: url),
            let pngData = svgImage.pngData() {
            
            let newImage = IncitoDataStore.ImageStorageType(data: pngData, mimeType: "image/png")
            let newCacheKey = svgCacheKey(url: url, containerSize: containerSize)
            
            return .success((newImage, newCacheKey))
        } else {
            return .error(IncitoError.unableToRenderSVG)
        }
    default:
        return .success((image, url.absoluteString))
    }
}

extension IncitoDataStore: ImageLoaderProtocol {
    public func imageData(forURL url: URL, containerSize: Size<Double>, completion: @escaping (Result<(data: Data, mimeType: String?)>) -> Void) {
        self.queue.async {
            
            // hit the cache with the url as the key
            self.imageStorage.async.object(forKey: url.absoluteString)
                // if that fails use the url prefixed with the size as the key
                .onError(self.imageStorage.async.object(forKey: svgCacheKey(url: url, containerSize: containerSize)))
                // if that fails, do a network request
                .onError(
                    URLSession.shared.imageRequest(url: url)
                        // apply a transform to the network result
                        .map({
                            $0.flatMap({ imageProperties in
                                imageLoadResponseTransform(imageProperties, url: url, containerSize: containerSize)
                            })
                        })
                        // if that succeeds, save the result to the cache
                        .mapResult({ (transformRes: (ImageStorageType, String)) -> ImageStorageType in
                            let (transformedImg, newCacheKey) = transformRes
                            
                            try? self.imageStorage.setObject(transformedImg, forKey: newCacheKey)
                            return transformedImg
                        })
                )
                // convert from ImageStorageType to tuple
                .mapResult({ ($0.data, $0.mimeType) })
                .run(completion)
        }
    }
}

extension IncitoDataStore: FontLoaderProtocol {
    public func fontData(forURL url: URL, completion: @escaping (Result<Data>) -> Void) {
        self.queue.async {
            self.fontStorage.async.object(forKey: url.absoluteString)
                .onError(
                    URLSession.shared.fontRequest(url: url)
                        .mapResult({ (font: FontStorageType) in
                            try! self.fontStorage.setObject(font, forKey: url.absoluteString)
                            return font
                        })
                )
                .mapResult({ $0.data })
                .run(completion)
        }
    }
}
