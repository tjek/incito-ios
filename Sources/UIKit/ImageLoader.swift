//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

import FLAnimatedImage
import SVGKit

// TODO:
//  - A proper cache
//  - Better network session setup
//  - Scale image to a specified size on bg queue
func loadImageView(_ request: ImageViewLoadRequest) {
    DispatchQueue.global().async {
        let urlSession = URLSession.shared
        let urlReq = URLRequest(url: request.url, timeoutInterval: 10)
        let task = urlSession.dataTask(with: urlReq) { data, response, error in
            
            let viewBuilder: (() -> UIImageView)? = {
                guard let imageData = data else {
                    print(" ❌ image load failed - no data", request.url)
                    return nil
                }
                
                switch response?.mimeType {
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
                        let image = SVGKExporterUIImage.export(asUIImage: svgImage)
                        return {
                            UIImageView(image: image)
                        }
                    }
                default:
                    if var image = UIImage(data: imageData) {
                        if let t = request.transform {
                            image = t(image)
                        }
                        return {
                            UIImageView(image: image)
                        }
                    } else {
                        print(" ❌ image load failed - unknown data type '\(response?.mimeType ?? "?")'", request.url)
                    }
                }
                
                return nil
            }()
            
            DispatchQueue.main.async {
                request.completion(viewBuilder?())
            }
        }

        task.resume()
    }
}
