//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

extension LoadedFontAsset {
    func font(size: CGFloat) -> UIFont? {
        return UIFont(name: self.fontName, size: size)
    }
}

extension UIFont {
    static func systemFont(forFamily family: FontFamily, size: Double) -> UIFont {
    
        let size = CGFloat(size)
        
        for familyName in family {
            if let systemFont = UIFont(name: familyName, size: size) {
                // try to use the family name to load a system font.
                return systemFont
            }
        }
        
        // nothing loadable, just use base system font (maybe take weight/style into account?)
        return UIFont.systemFont(ofSize: size)
    }
}

extension Collection where Element == LoadedFontAsset {
    func font(forFamily family: FontFamily, size: Double) -> UIFont {
        let size = CGFloat(size)
        
        for familyName in family {
            // try to get the asset with the family name
            if let asset = self.first(where: { $0.assetName == familyName }) {
                // The asset exists, but the font isnt loadable for some reason, go to the next family
                guard let font = asset.font(size: size) else {
                    continue
                }
                return font
            }
            else if let systemFont = UIFont(name: familyName, size: size) {
                // try to use the family name to load a system font.
                return systemFont
            }
        }
        
        // nothing loadable, just use base system font (maybe take weight/style into account?)
        return UIFont.systemFont(ofSize: size)
    }
}

enum FontLoadingError: Error {
    case invalidData // unable to convert data into a CGFont
    case registrationFailed
    case postscriptNameUnavailable
}

extension UIFont {
    /// Returns the name of the registered font, or nil if there is a problem.
    static func register(data: Data) throws -> String {
        
        guard let dataProvider = CGDataProvider(data: data as CFData),
            let cgFont = CGFont(dataProvider) else {
                throw(FontLoadingError.invalidData)
        }
        
        guard let fontName = cgFont.postScriptName else {
            throw(FontLoadingError.postscriptNameUnavailable)
        }
        
        // try to register the font. if it fails _but_ the font is still available (eg. it was already registered), then success!
        var error: Unmanaged<CFError>?
        if CTFontManagerRegisterGraphicsFont(cgFont, &error) == false,
            UIFont(name: String(fontName), size: 0) == nil {

            throw(FontLoadingError.registrationFailed)
        }
        
        return String(fontName)
    }
}

extension FontAssetLoader {
    // TODO: allow for different urlSession/cache properties
    static func uiKitFontAssetLoader() -> FontAssetLoader {
      
        let fontCache = FontAssetLoader.Cache(
            get: { _, completion in completion(nil) },
            set: { _, _ in }
        )
        
        let fontNetworkReq: FontAssetLoader.NetworkRequest = { sources, completion in
            
            let queue = DispatchQueue(label: "FontLoadingNetworkQ")
            let urlSession = URLSession.shared
            
            queue.async {
                let dispatchGroup = DispatchGroup()
                var complete: Bool = false
                for (source, sourceURL) in sources {
                    guard complete == false else {
                        return
                    }
                    
                    dispatchGroup.enter()
                    let urlReq = URLRequest(url: sourceURL,
                                            timeoutInterval: 2.0)
                    let task = urlSession.dataTask(with: urlReq) { (data, response, error) in
                        
                        defer {
                            dispatchGroup.leave()
                        }
                        
                        // TODO: what if timeout error?
                        guard let loadedData = data else {
                            return
                        }
                        
                        complete = true
                        completion((loadedData, (source, sourceURL)))
                    }
                    
                    task.resume()
                    
                    dispatchGroup.wait()
                }
                
                if complete == false {
                    completion(nil)
                }
            }
        }
        
        let fontLoader = FontAssetLoader(
            cache: fontCache,
            network: fontNetworkReq,
            registrator: UIFont.register(data:),
            supportedFontTypes: {
                // The order of these types defines the order we try to fetch them.
                var supportedTypes: [FontAsset.SourceType] = []

                // .woff_ only supported >= iOS 10
                if #available(iOS 10.0, *) {
                    supportedTypes += [
                        .woff2, // ✅ 23.2kb / -
                        .woff, // ✅ 29.4kb / 30.9kb
                    ]
                }
                
                // .otf & .ttf are default types, but larger than .woff
                supportedTypes += [
                    .opentype,
                    .truetype
                ]
                
                return supportedTypes
            }
        )
        
        return fontLoader
    }
}
