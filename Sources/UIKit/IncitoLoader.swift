//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

public struct IncitoLoader {
    public let load: (@escaping (Result<RenderableIncitoDocument>) -> Void) -> Void
    
    public init(_ load: @escaping (@escaping (Result<RenderableIncitoDocument>) -> Void) -> Void) {
        self.load = load
    }
}

enum IncitoLoaderError: Error {
    case unavailableFile(filename: String)
}

public func IncitoJSONFileLoader(filename: String, bundle: Bundle = .main, size: CGSize, queue: DispatchQueue = .global(qos: .userInitiated)) -> IncitoLoader {
    return IncitoLoader { completion in
        queue.async {
            do {
                guard let jsonFile = bundle.url(forResource: filename, withExtension: nil) else {
                    throw IncitoLoaderError.unavailableFile(filename: filename)
                }
                
                let jsonData = try Data(contentsOf: jsonFile)
                
                let dataLoader = IncitoJSONDataLoader(
                    data: jsonData,
                    size: size,
                    queue: queue
                )
                dataLoader.load(completion)
            } catch {
                completion(.error(error))
            }
        }
    }
}

public func IncitoJSONDataLoader(data: Data, size: CGSize, queue: DispatchQueue = .global(qos: .userInitiated)) -> IncitoLoader {
    return IncitoLoader { completion in
        queue.async {
            do {
                let start = Date.timeIntervalSinceReferenceDate
                
                let incitoDocument = try JSONDecoder().decode(
                    IncitoPropertiesDocument.self,
                    from: data
                )
                
                let end = Date.timeIntervalSinceReferenceDate
                print(" ⇢ 🤖 Decoded JSON document: \(String(format:"%.2f", Double(data.count) / 1024 / 1024)) Mb in \(round((end - start) * 1000))ms")
                
                let documentLoader = IncitoDocumentLoader(
                    document: incitoDocument,
                    size: size,
                    queue: queue
                )
                documentLoader.load(completion)
                
            } catch {
                completion(.error(error))
            }
        }
    }
}

public func IncitoDocumentLoader(document: IncitoPropertiesDocument, size: CGSize, queue: DispatchQueue = .global(qos: .userInitiated)) -> IncitoLoader {
    return IncitoLoader { completion in
        
        queue.async {
            
            var renderer = IncitoRenderer(
                fontProvider: UIFont.systemFont(forFamily:size:),
                imageViewLoader: loadImageView,
                theme: document.theme
            )
            
            // load fonts
            let fontLoader = FontAssetLoader.uiKitFontAssetLoader() // injectable?
            let fontAssets = document.fontAssets
            
            fontLoader.loadAndRegisterFontAssets(fontAssets) { (loadedAssets) in
                queue.async {
                    
                    // TODO: fail if font-load fails? or show crappy fonts?
                    let fontProvider = loadedAssets.font(forFamily:size:)
                    
                    // update the renderer's fontProvider
                    renderer.fontProvider = fontProvider
                    
                    let rootPropertiesNode = document.rootView
                    let defaultTextProperties = document.theme?.textDefaults ?? .empty
                    
                    let intrinsicSizer = uiKitViewSizer(
                        fontProvider: fontProvider,
                        textDefaults: defaultTextProperties
                    )
                    
                    print(" ⇢ 🚧 Building LayoutTree...")
                    let layoutTree: TreeNode<ViewLayout> = measure("   Total", timeScale: .milliseconds) {
                        
                        rootPropertiesNode.layout(
                            rootSize: Size(cgSize: size),
                            intrinsicSizerBuilder: intrinsicSizer
                        )
                        
                        }.result
                    
                    let renderableTree: RenderableViewTree = measure(" ⇢ 🚧 Renderable Tree", timeScale: .milliseconds) {
                        
                        layoutTree.buildRenderableViewTree(
                            rendererProperties: renderer,
                            nodeBuilt: { _ in
                                // TODO: a pass on setting up the incito
                                //                    [weak self] renderableView in
                                //                    guard let self = self else { return }
                                //                    self.delegate?.viewElementLoaded(
                                //                        viewProperties: renderableView.layout.viewProperties,
                                //                        incito: self.incitoDocument,
                                //                        in: self
                                //                    )
                        }
                        )
                        
                        }.result
                    
                    //        self.delegate?.documentLoaded(incito: self.incitoDocument, in: self)
                    //
                    //        if self.printDebugLayout {
                    //            let debugTree: TreeNode<String> = layoutTree.mapValues { layout, _, idx in
                    //
                    //                let name = layout.viewProperties.name ?? ""
                    //                let position = layout.position
                    //                let size = layout.size
                    //
                    //                var res = "\(idx)) \(name): [\(position)\(size)]"
                    //                if printDebugLayoutDetails {
                    //                    res += "\n\t dimensions: \(layout.dimensions)\n"
                    //                }
                    //
                    //                return res
                    //            }
                    //
                    //            print("\(debugTree)")
                    //        }
                    //        DispatchQueue.main.async { [weak self] in
                    //            self?.initializeRootView(parentSize: parentSize.cgSize)
                    //        }
                    
                    let renderableDocument = RenderableIncitoDocument(
                        id:  document.id,
                        version: document.version,
                        rootView: renderableTree,
                        locale: document.locale,
                        theme: document.theme,
                        meta: document.meta,
                        fontAssets: document.fontAssets
                    )
                    
                    // TODO: push completion to main?
                    completion(.success(renderableDocument))
                }
            }
        }
    }
}
