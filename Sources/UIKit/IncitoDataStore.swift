//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation
import GenericGeometry
import Future

class ImageStorageType: NSObject, NSCoding {
    var data: NSData
    var mimeType: String?
    
    init(data: NSData, mimeType: String?) {
        self.data = data
        self.mimeType = mimeType
    }
    
    static let cacheLifetime: TimeInterval = 86400 * 15 // 15 days
    
    enum Keys: String {
        case data, mimeType
    }
    func encode(with aCoder: NSCoder) {
        aCoder.encode(data, forKey: Keys.data.rawValue)
        aCoder.encode(mimeType, forKey: Keys.mimeType.rawValue)
    }
    required init?(coder aDecoder: NSCoder) {
        guard let data = aDecoder.decodeObject(forKey: Keys.data.rawValue) as? NSData else {
            return nil
        }
        self.data = data
        self.mimeType = aDecoder.decodeObject(forKey: Keys.data.rawValue) as? String
    }
}

class FontStorageType: NSObject, NSCoding {
    var data: NSData
    
    init(data: NSData) {
        self.data = data
    }
    
    static let cacheLifetime: TimeInterval = 86400 * 15 // 15 days
    
    enum Keys: String {
        case data
    }
    func encode(with aCoder: NSCoder) {
        aCoder.encode(data, forKey: Keys.data.rawValue)
    }
    required init?(coder aDecoder: NSCoder) {
        guard let data = aDecoder.decodeObject(forKey: Keys.data.rawValue) as? NSData else {
            return nil
        }
        self.data = data
    }
}

public class IncitoDataStore {
    public static let shared = IncitoDataStore()
    
    /// Removes all Images and Fonts from the disk & memory cache
    public func clearCache() {
        imageCache.removeAllObjects()
        fontCache.removeAllObjects()
    }
    
    fileprivate var queue = DispatchQueue(label: "IncitoDataStore", qos: .userInitiated)
    fileprivate let imageCache = try! Cache<ImageStorageType>(name: "imageCache", parentFolderName: "com.shopgun.incito.cache.v1")
    fileprivate let fontCache = try! Cache<FontStorageType>(name: "fontCache", parentFolderName: "com.shopgun.incito.cache.v1")
    
    init() {
        cleanOldCaches()
    }
    
    func cleanOldCaches() {
        // clean up any expired caches on first launch
        imageCache.removeExpiredObjects()
        fontCache.removeExpiredObjects()
        
        // remove the old cache from previouse cache lib (https://github.com/hyperoslo/Cache/)
        if let cacheFolderURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("Incito") {
            try? FileManager.default.removeItem(at: cacheFolderURL)
        }
    }
}

extension Cache {
    convenience init(name: String, parentFolderName: String) throws {
        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!

        try self.init(name: name, directory: url.appendingPathComponent("\(parentFolderName)/\(name)"))
    }
}

enum IncitoCacheError: Error {
    case fontNotInCache
    case imageNotInCache
}

extension IncitoDataStore {
    fileprivate func fetchImageFromCache(forKey key: String) -> FutureResult<ImageStorageType> {
        return FutureResult(work: { [unowned self] in
            return self.imageCache.object(forKey: key).map({ .success($0) }) ?? .failure(IncitoCacheError.imageNotInCache)
        }).async(on: .global())
    }
    
    fileprivate func saveImageToCache(imageData: ImageStorageType, forKey key: String) {
        DispatchQueue.global().async { [unowned self] in
            self.imageCache.setObject(imageData, forKey: key, expires: .seconds(ImageStorageType.cacheLifetime))
        }
    }
    
    fileprivate func fetchFontFromCache(forKey key: String) -> FutureResult<FontStorageType> {
        return FutureResult(work: { [unowned self] in
            return self.fontCache.object(forKey: key).map({ .success($0) }) ?? .failure(IncitoCacheError.fontNotInCache)
        }).async(on: .global())
    }
    
    fileprivate func saveFontToCache(fontData: FontStorageType, forKey key: String) {
        DispatchQueue.global().async { [unowned self] in
            self.fontCache.setObject(fontData, forKey: key, expires: .seconds(FontStorageType.cacheLifetime))
        }
    }
}

enum IncitoError: Error {
    case unknownImageRequestError
    case unknownFontRequestError
    case unableToRenderSVG
}

extension URLSession {
    
    fileprivate func imageRequest(url: URL) -> FutureResult<ImageStorageType> {
        let urlReq = URLRequest(url: url, timeoutInterval: 10)
        return self.dataTaskFutureResult(with: urlReq)
            .mapResult({ ImageStorageType(data: $0.data as NSData, mimeType: $0.response.mimeType) })
    }
    
    fileprivate func fontRequest(url: URL) -> FutureResult<FontStorageType> {
        let urlReq = URLRequest(url: url, timeoutInterval: 10)
        return self.dataTaskFutureResult(with: urlReq)
            .mapResult({ FontStorageType(data: $0.data as NSData) })
    }
}

fileprivate func svgCacheKey(url: URL, containerSize: Size<Double>) -> String {
    return "\(containerSize.width)x\(containerSize.height):\(url.absoluteString)"
}

fileprivate func imageLoadResponseTransform(_ image: ImageStorageType, url: URL, containerSize: Size<Double>) -> Swift.Result<(image: ImageStorageType, cacheKey: String), Error> {
    
    switch image.mimeType {
    case "image/svg+xml"?:
        if let svgImage = SharedHTMLImageRenderer.renderImageURL(url, containerSize: containerSize),
            let pngData = svgImage.pngData() {
            
            let newImage = ImageStorageType(data: pngData as NSData, mimeType: "image/png")
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
            self.fetchImageFromCache(forKey: url.absoluteString)
                // if that fails use the url prefixed with the size as the key
                .flatMapResultError({ [unowned self] _ in
                    self.fetchImageFromCache(forKey: svgCacheKey(url: url, containerSize: containerSize))
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
                        .mapResult({ [unowned self] (transformRes: (ImageStorageType, String)) -> ImageStorageType in
                            let (transformedImg, newCacheKey) = transformRes
                            self.saveImageToCache(imageData: transformedImg, forKey: newCacheKey)
                            return transformedImg
                        })
                })
                // convert from ImageStorageType to tuple
                .mapResult({ ($0.data as Data, $0.mimeType) })
                .run(completion)
        }
    }
}

extension IncitoDataStore: FontLoaderProtocol {
    public func fontData(forURL url: URL, completion: @escaping (Swift.Result<Data, Error>) -> Void) {
        self.queue.async { [unowned self] in
            self.fetchFontFromCache(forKey: url.absoluteString)
                .flatMapResultError({ _ in
                    URLSession.shared.fontRequest(url: url)
                        .mapResult({ [unowned self] (font: FontStorageType) in
                            self.saveFontToCache(fontData: font, forKey: url.absoluteString)
                            return font
                        })
                })
                .mapResult({ $0.data as Data })
                .run(completion)
        }
    }
}
