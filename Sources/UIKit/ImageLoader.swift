//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

private var imageDataParserQueue = DispatchQueue(label: "ImageDataParserQueue", qos: .userInitiated)

func loadImageView(request: ImageViewLoadRequest) {
    // how long to wait before first asking the request if we are still visible, and then doing the request.
    let debounceDelay: TimeInterval = 0.2
    
    Future<URL?>(run: { cb in
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceDelay) {
            guard request.stillVisibleCheck() else {
                cb(nil)
                return
            }
            cb(request.url)
        }
    })
        .flatMap(IncitoEnvironment.current.imageLoader.imageData(forURL:))
        .map({ (data: $0.data, mimeType: $0.mimeType, request.containerSize, request.transform) })
        .flatMap(buildImageView(imageData:mimeType:containerSize:transform:))
        .run(request.completion)
}

extension ImageLoaderProtocol {
    func imageData(forURL url: URL) -> Future<(data: Data, mimeType: String?)?> {
        return Future { cb in
            self.imageData(forURL: url) {
                cb($0.value)
            }
        }
    }
}

import FLAnimatedImage
import SVGKit

// when run, the future's completion will be called on the main queue
func buildImageView(imageData: Data, mimeType: String?, containerSize: CGSize, transform: ((UIImage) -> UIImage)?) -> Future<UIImageView?> {
    
    return Future { completion in
        
        // does the loading of the image
        let viewBuilder: (() -> UIImageView)? = {
            
            switch mimeType {
            case "image/gif"?:
                if let gifImage = FLAnimatedImage(gifData: imageData) {
                    // if it is a gif with only a single image, dont use the animatedImageView
                    if gifImage.frameCount == 1, let image = gifImage.posterImage {
                        return {
                            UIImageView(image: image)
                        }
                    } else {
                        return {
                            let view = FLAnimatedImageView()
                            view.animatedImage = gifImage
                            return view
                        }
                    }
                }
            case "image/svg+xml"?:
                if let svgImage = SVGKImage(data: imageData) {
                    if svgImage.hasSize(),
                        containerSize.width != 0, containerSize.height != 0 {
                        let currentSize = svgImage.size
                        // scale to fit in container
                        let scaleFactor = max(currentSize.width / containerSize.width,
                                              currentSize.height / containerSize.height)
                        let newSize = CGSize(width: currentSize.width / scaleFactor,
                                             height: currentSize.height / scaleFactor)
                        svgImage.size = newSize
                    }
                    
                    let image = SVGKExporterUIImage.export(asUIImage: svgImage)
                    return {
                        UIImageView(image: image)
                    }
                }
            default:
                if var image = UIImage(data: imageData) {
                    if let t = transform {
                        image = t(image)
                    }
                    return {
                        UIImageView(image: image)
                    }
                } else {
                    print(" ❌ image load failed - unknown data type '\(mimeType ?? "?")'")
                }
            }
            
            return nil
        }()
        
        DispatchQueue.main.async {
            let imageView = viewBuilder?()
            completion(imageView)
        }
    }.async(on: imageDataParserQueue, completesOn: .main)
}
