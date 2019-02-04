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
    
    func loadAndRegisterFontAssets(_ fontAssets: [String: FontAsset]) -> Future<Result<[LoadedFontAsset]>> {
        
        // build an array of Future<Result<[LoadedFontAsset]>>
        // each of these futures would go out and load the fontAsset
        let assetFutures = fontAssets
            .map({
                self.loadAndRegisterFontAsset($0.value, assetName: $0.key)
            })
        
        return Future<Result<[LoadedFontAsset]>> { cb in
            let queue = DispatchQueue(label: "FontLoadingCompletionQ")

            let group = DispatchGroup()
            var result: Result<[LoadedFontAsset]> = .success([])
            
            for future in assetFutures {
                group.enter()
                
                // run each assetFuture on a bg queue, combining them on success.
                future
                    .async(on: .global(), completesOn: queue)
                    .run {
                        defer { group.leave() }
                        guard case .success(let loadedAssets) = result else {
                            return
                        }
                        
                        switch $0 {
                        case let .success(loadedAsset):
                            result = .success(loadedAssets + [loadedAsset])
                        case let .error(error):
                            result = .error(error)
                        }
                }
            }
            group.wait()
            
            cb(result)
        }
    }

    func loadAndRegisterFontAsset(_ asset: FontAsset, assetName: String) -> Future<Result<LoadedFontAsset>> {
        return Future { completion in
            
            let sources: [FontAsset.FontSource] = self.supportedFontTypes().compactMap { sourceType in
                return asset.sources.first(where: { $0.0 == sourceType })
            }
            
            let fontDataLoaded: (Result<(Data, FontAsset.FontSource)>) -> Void = {
                
                switch $0 {
                case let .error(err):
                    completion(.error(err))
                case let .success((loadedData, source)):
                    do {
                        let registeredName = try self.registrator(loadedData)
                        
                        let loadedAsset = LoadedFontAsset(
                            assetName: assetName,
                            fontName: registeredName,
                            source: source,
                            asset: asset
                        )
                        completion(.success(loadedAsset))
                    } catch {
                        completion(.error(error))
                    }
                }
            }
            
            // try to get the data from the cache.
            self.cache.get(sources) { cacheResult in
                if let cacheSuccess = cacheResult {
                    fontDataLoaded(.success(cacheSuccess))
                    return
                }
                
                // if that fails, try to get it from the network
                self.network(sources) { networkResult in
                    
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
}
