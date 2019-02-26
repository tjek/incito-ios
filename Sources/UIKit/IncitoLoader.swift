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

public func IncitoJSONFileLoader(
    filename: String,
    bundle: Bundle = .main,
    width: Double
    ) -> IncitoLoader {
    
    // - open the specified file
    // - decode the json into an IncitoPropertiesDocument
    // - convert into a RenderableIncitoDocument, using the size
    // - make sure this all happens asyncronously
    return openFile(filename: filename, bundle: bundle)
        .flatMapResult(IncitoPropertiesDocument.decode(from:))
        .flatMapResult({ IncitoDocumentLoader(document: $0, width: width) })
}

public func IncitoDocumentLoader(
    document: IncitoPropertiesDocument,
    width: Double
    ) -> IncitoLoader {
    
    let fontLoader = FontAssetLoader.uiKitFontAssetLoader
    
    return fontLoader
        .loadAndRegisterFontAssets(document.fontAssets)
        .flatMap({ buildRenderableDocument(document: document, width: width, loadedAssets: $0.assets) })
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

func buildRenderableDocument(
    document: IncitoPropertiesDocument,
    width: Double,
    loadedAssets: [LoadedFontAsset]
    ) -> Future<Result<RenderableIncitoDocument>> {
    return Future { completion in
        let fontProvider = loadedAssets.font(forFamily:size:style:)
        
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
                rootSize: Size(width: width, height: 0),
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
