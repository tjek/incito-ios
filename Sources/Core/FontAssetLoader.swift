//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

struct FontAssetLoader {
    typealias Registrator = (Data) throws -> String
    typealias NetworkRequest = ([FontAsset.FontSource], @escaping (Result<(Data, FontAsset.FontSource)>) -> Void) -> Void
    
    struct Cache {
        var get: ([FontAsset.FontSource], ((Data, FontAsset.FontSource)?) -> Void) -> Void
        var set: (Data, FontAsset.FontSource) -> Void
    }
    
    var cache: Cache
    var network: NetworkRequest
    var registrator: Registrator
    
    /// the order here is the order we prioritize when fetching
    var supportedFontTypes: () -> [FontAsset.SourceType]
}

struct LoadedFontAsset {
    var assetName: FontAssetName
    var fontName: String
    var source: FontAsset.FontSource
    
    var asset: FontAsset
}

extension FontAssetLoader {
    
    func loadAndRegisterFontAssets(
        _ fontAssets: [String: FontAsset],
        completion: @escaping ([LoadedFontAsset]) -> Void
        ) {
        
        let dispatchGroup = DispatchGroup()
        let queue = DispatchQueue(label: "FontLoadingCompletionQ")
        
        var loadedAssets: [LoadedFontAsset] = []
        
        for (name, asset) in fontAssets {
            dispatchGroup.enter()
            
            loadAndRegisterFontAsset(asset) { result in
                queue.sync {
                    defer { dispatchGroup.leave() }
                    
                    guard let (fontName, source) = result.value else {
                        return
                    }
                    
                    loadedAssets.append(LoadedFontAsset(
                        assetName: name,
                        fontName: fontName,
                        source: source,
                        asset: asset
                    ))
                }
            }
        }
        dispatchGroup.wait()
        
        completion(loadedAssets)
    }
    
    func loadAndRegisterFontAsset(
        _ asset: FontAsset,
        completion: @escaping (Result<(String, FontAsset.FontSource)>) -> Void
        ) {
        
        let sources: [FontAsset.FontSource] = supportedFontTypes().compactMap { sourceType in
            return asset.sources.first(where: { $0.0 == sourceType })
        }
        
        let fontDataLoaded: (Result<(Data, FontAsset.FontSource)>) -> Void = {
            
            switch $0 {
            case let .error(err):
                completion(.error(err))
            case let .success((loadedData, source)):
                do {
                    let registeredName = try self.registrator(loadedData)
                    completion(.success((registeredName, source)))
                } catch {
                    completion(.error(error))
                }
            }
        }
        
        // try to get the data from the cache.
        cache.get(sources) { cacheResult in
            if let cacheSuccess = cacheResult {
                fontDataLoaded(.success(cacheSuccess))
                return
            }
            
            // if that fails, try to get it from the network
            network(sources) { networkResult in
                
                switch networkResult {
                case let .error(err):
                    fontDataLoaded(.error(err))
                case let .success((loadedData, source)):
                    
                    self.cache.set(loadedData, source)
                    
                    fontDataLoaded(.success((loadedData, source)))
                }
            }
        }
    }
}
