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

// TODO: not like this.
func loadImageView(url: URL, completion: @escaping (UIView?) -> Void) {
    DispatchQueue.global().async {
        let urlSession = URLSession.shared
        let urlReq = URLRequest(url: url, timeoutInterval: 10)
        let task = urlSession.dataTask(with: urlReq) { data, response, error in
            
            let viewBuilder: (() -> UIView)? = {
                guard let imageData = data else {
                    print(" ❌ image load failed - no data", url)
                    return nil
                }
                
                switch response?.mimeType {
                case "image/gif"?:
                    if let gifImage = FLAnimatedImage(gifData: imageData) {
                        return {
                            let view = FLAnimatedImageView()
                            view.animatedImage = gifImage
                            return view
                        }
                    }
                default:
                    if let image = UIImage(data: imageData) {
                        return {
                            UIImageView(image: image)
                        }
                    } else {
                        print(" ❌ image load failed - unknown data type '\(response?.mimeType ?? "?")'", url)
                    }
                }
                
                return nil
            }()
            
            DispatchQueue.main.async {
                completion(viewBuilder?())
            }
        }

        task.resume()
    }
}
