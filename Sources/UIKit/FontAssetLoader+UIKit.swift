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

extension TextStyle {
    var symbolicTraits: UIFontDescriptor.SymbolicTraits {
        switch self {
        case .normal:
            return []
        case .bold:
            return .traitBold
        case .italic:
            return .traitItalic
        case .boldItalic:
            return [.traitBold, .traitItalic]
        }
    }
}

extension UIFont {
    func withSymbolicTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        if !traits.isEmpty,
            let fontDesc = self.fontDescriptor.withSymbolicTraits(traits) {
            return UIFont(descriptor: fontDesc, size: 0.0)
        } else {
            return self
        }
    }
}

extension Collection where Element == LoadedFontAsset {
    func font(forFamily family: FontFamily, size: Double, style: TextStyle = .normal) -> UIFont {
        
        let size = CGFloat(size)
        let traits = style.symbolicTraits
        
        for familyName in family {
            
            let fontName = self.first(where: { $0.assetName == familyName })?.fontName ?? familyName

            guard let matchingFont = UIFont(name: fontName, size: size)?.withSymbolicTraits(traits) else {
                continue
            }
            
            return matchingFont
        }
        
        // nothing loadable, just use base system font.
        return UIFont.systemFont(ofSize: size).withSymbolicTraits(traits)
    }
}

private let uiFontRegistrationQueue = DispatchQueue(label: "UIFontRegistrationQueue")
private var lastRegisteredFont: (name: String, timestamp: TimeInterval)?

extension UIFont {
    
    /// Returns the name of the registered font, or nil if there is a problem.
    static func register(data: Data) throws -> String {
        return try uiFontRegistrationQueue.sync {
            
            func makeFont(data: Data) throws -> (font: CGFont, postscriptName: String) {
                guard let dataProvider = CGDataProvider(data: data as CFData),
                    let cgFont = CGFont(dataProvider) else {
                        throw(FontLoadingError.invalidData)
                }
                
                guard let fontName = cgFont.postScriptName.map({ String($0) }) else {
                    throw(FontLoadingError.postscriptNameUnavailable)
                }
                
                // user fonts must not have a "." prefix - that is system-only
                if fontName.hasPrefix(".") {
                    throw(FontLoadingError.invalidPostscriptName)
                }
                
                return (cgFont, fontName)
            }
            
            let timestamp = Date().timeIntervalSinceReferenceDate
            
            // make the font and get the postscript name
            var (cgFont, fontName) = try makeFont(data: data)
            
            // NOTE: The name provided here for fonts that lack a postscript name
            // is along the lines of `font000000002301a318`
            // where `000000002301a318` is the hex version of `Date().timeIntervalSinceReferenceDate` in secs
            // This means that fonts registered within the same second are given the same name, and problems ensue.
            
            // Check if we have previously registered a font, and it's name is the same as the last registered font,
            // AND its name starts with `font0`.
            // in which case we have hit the bug described above :/
            // so the horrible solution is to just sleep for the difference until a new second has passed
            if let (lastName, lastTimestamp) = lastRegisteredFont,
                lastName == fontName,
                fontName.hasPrefix("font0") {
                // find the time difference between now and the next second.
                let timestampDiff = min(TimeInterval(floor(lastTimestamp) + 1) - timestamp + 0.001, 1)
                
                // wait for that difference
                let grp = DispatchGroup()
                grp.enter()
                _ = grp.wait(timeout: .now() + timestampDiff)

                // try to re-make the font
                (cgFont, fontName) = try makeFont(data: data)

                // waiting didnt seem to work - this font has the same name, so eject!
                if fontName == lastName {
                    debugPrint("❌ Font name conflict: '\(fontName)'")
                    throw FontLoadingError.duplicatePostscriptName
                }
            }
            
            // try to register the font. if it fails _but_ the font is still available (eg. it was already registered), then success!
            var error: Unmanaged<CFError>?
            defer {
                error?.release()
            }
            if CTFontManagerRegisterGraphicsFont(cgFont, &error) == false,
                UIFont(name: fontName, size: 0) == nil {
                
                throw(FontLoadingError.registrationFailed)
            }
            
            lastRegisteredFont = (fontName, timestamp)
            
            return String(fontName)
        }
    }
}

extension FontAssetLoader {
    // TODO: allow for different urlSession/cache properties
    static let uiKitFontAssetLoader = FontAssetLoader(
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
    })
}
