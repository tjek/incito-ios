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

extension IncitoDataStore: ImageLoaderProtocol {
    public func imageData(forURL url: URL, completion: @escaping (Result<(data: Data, mimeType: String?)>) -> Void) {
        self.queue.async {
            self.imageStorage.async.object(forKey: url.absoluteString)
                .onError(
                    URLSession.shared.imageRequest(url: url)
                        .map({ (img: ImageStorageType) in
                            try? self.imageStorage.setObject(img, forKey: url.absoluteString)
                            return img
                        })
                )
                .map({ (img: IncitoDataStore.ImageStorageType) in
                    return (img.data, img.mimeType)
                })
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
                        .map({ (font: FontStorageType) in
                            try! self.fontStorage.setObject(font, forKey: url.absoluteString)
                            return font
                        })
                )
                .map({ (font: IncitoDataStore.FontStorageType) in
                    return font.data
                })
                .run(completion)
        }
    }
}
