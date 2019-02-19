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
    
    func loadAndRegisterFontAssets(_ fontAssets: [String: FontAsset]) -> Future<(assets: [LoadedFontAsset], errors: [Error])> {
        
        // build an array of Future<Result<[LoadedFontAsset]>>
        // each of these futures would go out and load the fontAsset
        let assetFutures = fontAssets
            .map({
                self.loadAndRegisterFontAsset($0.value, assetName: $0.key)
            })
        
        return Future<(assets: [LoadedFontAsset], errors: [Error])> { cb in
            let queue = DispatchQueue(label: "FontLoadingCompletionQ")

            let group = DispatchGroup()

            var loadedAssets: [LoadedFontAsset] = []
            var errors: [Error] = []
            for future in assetFutures {
                group.enter()
                
                // run each assetFuture on a bg queue, combining them on success.
                future
                    .async(on: .global(), completesOn: queue)
                    .run {
                        switch $0 {
                        case let .success(loadedAsset):
                            loadedAssets += [loadedAsset]
                        case let .error(error):
                            errors += [error]
                        }
                        group.leave()
                }
            }
            group.wait()
            
            cb((loadedAssets, errors))
        }
    }

    func loadAndRegisterFontAsset(_ asset: FontAsset, assetName: String) -> Future<Result<LoadedFontAsset>> {
        return Future { completion in
            
            // get all the supported source files
            let sources: [FontAsset.FontSource] = self.supportedFontTypes().compactMap { sourceType in
                return asset.sources.first(where: { $0.0 == sourceType })
            }
            
            let dispatchGroup = DispatchGroup()
            var complete: Bool = false
            var lastError: Error? = nil
            
            for (source, sourceURL) in sources {
                dispatchGroup.enter()
                
                IncitoEnvironment.current.fontLoader.fontData(forURL: sourceURL) { result in
                    defer {
                        dispatchGroup.leave()
                    }
                    
                    switch result {
                    case let .success(loadedData):
                        do {
                            let registeredName = try self.registrator(loadedData)
                            
                            let loadedAsset = LoadedFontAsset(
                                assetName: assetName,
                                fontName: registeredName,
                                source: (source, sourceURL),
                                asset: asset
                            )
                            complete = true
                            completion(.success(loadedAsset))
                        } catch {
                            lastError = error
                        }
                        
                    case let .error(error):
                        lastError = error
                    }
                }
                
                dispatchGroup.wait()
                // no more looping if we have called completion
                if complete {
                    return
                }
            }
            
            // we made it to the end without loading any of the sources. Error!
            completion(.error(lastError ?? FontLoadingError.unknownError))
        }
    }
}
