//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

// TODO: not like this.
func loadImage(url: URL, completion: @escaping (UIImage?) -> Void) {
    
    let urlSession = URLSession.shared
    let urlReq = URLRequest(url: url, timeoutInterval: 2)
    let task = urlSession.dataTask(with: urlReq) { data, response, error in
        DispatchQueue.main.async {
            
            guard let imageData = data,
                let image = UIImage(data: imageData) else {
                    print(" ❌ image load failed ", url)
                    completion(nil)
                    return
            }
            //        print(" ✅ image load success ", url.lastPathComponent)
            completion(image)
            
        }   
    }
    
    task.resume()
}
