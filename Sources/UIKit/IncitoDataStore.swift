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
import GenericGeometry

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
    func objectFuture(forKey key: String) -> FutureResult<T> {
        return FutureResult<T> { cb in
            self.object(forKey: key, completion: { res in
                switch res {
                case let .value(t):
                    cb(.success(t))
                case let .error(err):
                    cb(.failure(err))
                }
            })
        }
    }
}

enum IncitoError: Error {
    case unknownImageRequestError
    case unknownFontRequestError
    case unableToRenderSVG
}

extension URLSession {
    
    fileprivate func imageRequest(url: URL) -> FutureResult<IncitoDataStore.ImageStorageType> {
        return Future { completion in
            let urlReq = URLRequest(url: url, timeoutInterval: 10)
            let task = self.dataTask(with: urlReq) { data, response, error in
                
                guard let imageData = data else {
                    completion(.failure(error ?? IncitoError.unknownImageRequestError))
                    return
                }
                
                completion(.success(.init(data: imageData, mimeType: response?.mimeType)))
            }
            task.resume()
        }
    }
    
    fileprivate func fontRequest(url: URL) -> FutureResult<IncitoDataStore.FontStorageType> {
        return Future { completion in
            let urlReq = URLRequest(url: url, timeoutInterval: 10)
            let task = self.dataTask(with: urlReq) { data, response, error in
                
                guard let fontData = data else {
                    completion(.failure(error ?? IncitoError.unknownFontRequestError))
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

fileprivate func imageLoadResponseTransform(_ image: IncitoDataStore.ImageStorageType, url: URL, containerSize: Size<Double>) -> Swift.Result<(image: IncitoDataStore.ImageStorageType, cacheKey: String), Error> {
    
    switch image.mimeType {
    case "image/svg+xml"?:
        if let svgImage = SharedHTMLImageRenderer.renderImageURL(url, containerSize: containerSize),
            let pngData = svgImage.pngData() {
            
            let newImage = IncitoDataStore.ImageStorageType(data: pngData, mimeType: "image/png")
            let newCacheKey = svgCacheKey(url: url, containerSize: containerSize)
            
            return .success((newImage, newCacheKey))
        } else {
            return .failure(IncitoError.unableToRenderSVG)
        }
    default:
        return .success((image, url.absoluteString))
    }
}

extension IncitoDataStore: ImageLoaderProtocol {
    public func imageData(forURL url: URL, containerSize: Size<Double>, completion: @escaping (Swift.Result<(data: Data, mimeType: String?), Error>) -> Void) {
        self.queue.async {
            
            // hit the cache with the url as the key
            self.imageStorage.async.objectFuture(forKey: url.absoluteString)
                // if that fails use the url prefixed with the size as the key
                .flatMapResultError({ _ in
                    self.imageStorage.async.objectFuture(forKey: svgCacheKey(url: url, containerSize: containerSize))
                })
                // if that fails, do a network request
                .flatMapResultError({ _ in
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
                })
                // convert from ImageStorageType to tuple
                .mapResult({ ($0.data, $0.mimeType) })
                .run(completion)
        }
    }
}

extension IncitoDataStore: FontLoaderProtocol {
    public func fontData(forURL url: URL, completion: @escaping (Swift.Result<Data, Error>) -> Void) {
        self.queue.async {
            self.fontStorage.async.objectFuture(forKey: url.absoluteString)
                .flatMapResultError({ _ in URLSession.shared.fontRequest(url: url)
                    .mapResult({ (font: FontStorageType) in
                        try! self.fontStorage.setObject(font, forKey: url.absoluteString)
                        return font
                    })
                })
                .mapResult({ $0.data })
                .run(completion)
        }
    }
}
