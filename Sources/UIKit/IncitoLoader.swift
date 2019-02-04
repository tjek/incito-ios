//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

public typealias IncitoLoader = Future<Result<RenderableIncitoDocument>>

public func IncitoJSONFileLoader(filename: String, bundle: Bundle = .main, size: CGSize, queue: DispatchQueue = .global(qos: .userInitiated)) -> IncitoLoader {
    // - open the specified file
    // - decode the json into an IncitoPropertiesDocument
    // - convert into a RenderableIncitoDocument, using the size
    // - make sure this all happens asyncronously
    return openFile(filename: filename, bundle: bundle)
        .flatMap(IncitoPropertiesDocument.decode(from:))
        .flatMap({ buildRenderableDocument(document: $0, size: size) })
        .async(on: queue, completesOn: .main)
}

public func IncitoDocumentLoader(document: IncitoPropertiesDocument, size: CGSize, queue: DispatchQueue = .global(qos: .userInitiated)) -> IncitoLoader {
    
    return
        buildRenderableDocument(document: document, size: size)
            .async(on: queue, completesOn: .main)
}

enum IncitoLoaderError: Error {
    case unavailableFile(filename: String)
}

func openFile(filename: String, bundle: Bundle = .main) -> Future<Result<Data>> {
    return Future<Result<Data>> { completion in
        completion(Result {
            guard let fileURL = bundle.url(forResource: filename, withExtension: nil) else {
                throw IncitoLoaderError.unavailableFile(filename: filename)
            }
            
            return try Data(contentsOf: fileURL)
        })
    }
}

func buildRenderableDocument(document: IncitoPropertiesDocument, size: CGSize, loadedAssets: [LoadedFontAsset]) -> Future<Result<RenderableIncitoDocument>> {
    return Future { completion in
        let fontProvider = loadedAssets.font(forFamily:size:)
        
        let renderer = IncitoRenderer(
            fontProvider: fontProvider,
            imageViewLoader: loadImageView,
            theme: document.theme
        )
        
        let rootPropertiesNode = document.rootView
        let defaultTextProperties = document.theme?.textDefaults ?? .empty
        
        let intrinsicSizer = uiKitViewSizer(
            fontProvider: fontProvider,
            textDefaults: defaultTextProperties
        )
        
        let layoutTree = rootPropertiesNode
            .layout(
                rootSize: Size(cgSize: size),
                intrinsicSizerBuilder: intrinsicSizer
        )
        
        let renderableTree = layoutTree
            .buildRenderableViewTree(
                rendererProperties: renderer,
                nodeBuilt: { _ in }
        )
        
        let renderableDocument = RenderableIncitoDocument(
            id:  document.id,
            version: document.version,
            rootView: renderableTree,
            locale: document.locale,
            theme: document.theme,
            meta: document.meta,
            fontAssets: document.fontAssets
        )
        completion(.success(renderableDocument))
    }
}

func buildRenderableDocument(document: IncitoPropertiesDocument, size: CGSize) -> Future<Result<RenderableIncitoDocument>> {
    
    // load fonts
    let fontLoader = FontAssetLoader.uiKitFontAssetLoader() // injectable?
    
    return fontLoader
        .loadAndRegisterFontAssets(document.fontAssets)
        .flatMap({ buildRenderableDocument(document: document, size: size, loadedAssets: $0) })
}


func decodeJSON<B: Decodable>(data: Data) -> Future<Result<B>> {
    return Future<Result<B>> { completion in
        completion(Result {
            try JSONDecoder().decode(B.self, from: data)
        })
    }
}

extension Decodable {
    public static func decode(from data: Data) -> Future<Result<Self>> {
        return decodeJSON(data: data)
    }
}
