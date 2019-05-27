//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit
import GenericGeometry
import Future

public typealias IncitoLoader = FutureResult<RenderableIncitoDocument>

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
        .flatMapResult(decodeIncitoDocument)
        .flatMapResult({ IncitoDocumentLoader(document: $0, width: width) })
}

/**
 Creates an IncitoLoader based on a properties document and width into which it will be placed.
 
 Under the hood it will, on a background queue, load and register the fonts from the document, and then build the renderable document by calculating the layout properties for the document. Finally it completes on the main queue.
 */
public func IncitoDocumentLoader(
    document: IncitoPropertiesDocument,
    width: Double
    ) -> IncitoLoader {
    
    let fontLoader = FontAssetLoader.uiKitFontAssetLoader
    
    return fontLoader
        .loadAndRegisterFontAssets(document.fontAssets)
//        .measure(print: " 🔠 Fonts loaded")
        .flatMap({
            buildRenderableDocument(document: document, width: width, loadedAssets: $0.assets)
//                .measure(print: " 📐 Layouts calculated")
        })
        .async(on: .global(), completesOn: .main)
}

enum IncitoLoaderError: Error {
    case unavailableFile(filename: String)
}

func openFile(filename: String, bundle: Bundle = .main) -> FutureResult<Data> {
    return FutureResult<Data> { completion in
        completion(Result {
            guard let fileURL = bundle.url(forResource: filename, withExtension: nil) else {
                throw IncitoLoaderError.unavailableFile(filename: filename)
            }
            
            return try Data(contentsOf: fileURL)
        })
    }
}

func decodeIncitoDocument(jsonData: Data) -> FutureResult<IncitoPropertiesDocument> {
    return Future(work: {
        Result.init(catching: { try IncitoPropertiesDocument(jsonData: jsonData) })
    })
}

func buildRenderableDocument(
    document: IncitoPropertiesDocument,
    width: Double,
    loadedAssets: [LoadedFontAsset]
    ) -> Future<Result<RenderableIncitoDocument, Error>> {
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
        
        let systemGravity: HorizontalGravity = UIView.userInterfaceLayoutDirection(for: .unspecified) == .leftToRight ? .left : .right
        
        let layoutTree = rootPropertiesNode
            .layout(
                rootSize: Size(width: width, height: 0),
                intrinsicSizerBuilder: intrinsicSizer,
                systemGravity: systemGravity
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
