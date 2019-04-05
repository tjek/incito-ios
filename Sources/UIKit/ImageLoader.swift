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

func loadImageView(request: ImageViewLoadRequest) {
    // how long to wait before first asking the request if we are still visible, and then doing the request.
    let debounceDelay: TimeInterval = 0.2
    
    // first, wait a bit and then check if image is still visible.
    // if not then pass nil through
    Future<(URL, Size<Double>)?>(run: { cb in
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceDelay) {
            guard request.stillVisibleCheck() else {
                cb(nil)
                return
            }
            cb((request.url, Size<Double>(cgSize: request.containerSize)))
        }
    })
        // if not not nil, load the image data
        .flatMapOptional(
            IncitoEnvironment.current.imageLoader
                .imageData(forURL:containerSize:)
        )
        // if not nil, expand the info in the tuple
        .mapOptional({
            (url: request.url, data: $0.data, mimeType: $0.mimeType, request.containerSize, request.transform)
        })
        // if not nil, build the image view
        .flatMapOptional(
            buildImageView(sourceURL:imageData:mimeType:containerSize:transform:)
        )
        // finally run the future
        .run(request.completion)
}

extension ImageLoaderProtocol {
    func imageData(forURL url: URL, containerSize: Size<Double>)
        -> Future<(data: Data, mimeType: String?)?> {
            
            return Future { cb in
                self.imageData(forURL: url, containerSize: containerSize, completion: {
                    cb($0.getSuccess())
                })
            }
    }
}

import FLAnimatedImage

// when run, the future's completion will be called on the main queue
func buildImageView(sourceURL: URL, imageData: Data, mimeType: String?, containerSize: CGSize, transform: ((UIImage) -> UIImage)?) -> Future<UIImageView?> {
    
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
                // if for some reason the imageloader cache transformer failed, render the SVG here.
                if let svgImage = SharedHTMLImageRenderer.renderSVG(imageData, containerSize: Size<Double>(cgSize: containerSize), baseURL: sourceURL) {
                    return {
                        UIImageView(image: svgImage)
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
                    print(" ❌ image load failed - unknown data type '\(mimeType ?? "?")'", sourceURL)
                }
            }
            
            return nil
        }()
        
        DispatchQueue.main.async {
            let imageView = viewBuilder?()
            completion(imageView)
        }
    }.async(on: .global(qos: .userInitiated), completesOn: .main)
}
