//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

extension UIColor {
    
    /**
     Tries to create a UIColor out of the provided `webString`.
     
     This can be in the form
     - `rgb(0.5, 0.6, 0.7)` or `rgb(50%, 0.6, 70%)`
     - `rgba(0.5, 0.6, 0.7, 0.8)` or `rgba(50%, 60%, 0.7, 80%)`
     - `#FFAABB` or `#FFAABBCC`
     */
    public convenience init?(webString: String) {
        let cleanedStrVal = webString.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanedStrVal == "transparent" {
            self.init(red: 0, green: 0, blue: 0, alpha: 0)
            return
        }
        
        if let color = cleanedStrVal.starts(with: "rgb") ? UIColor.scanRGBColorStr(cleanedStrVal) : UIColor.scanHexColorStr(cleanedStrVal) {
            self.init(cgColor: color.cgColor)
            return
        }
        
        return nil
    }
    
    private static func scanRGBColorStr(_ strVal: String) -> UIColor? {
        let components: [CGFloat?] = strVal
            .lowercased()
            .replacingOccurrences(of: "rgba(", with: "")
            .replacingOccurrences(of: "rgb(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .components(separatedBy: ",")
            .map {
                var strVal: String = $0
                
                var scaleFactor = 255.0
                if strVal.contains("%") {
                    strVal = strVal.replacingOccurrences(of: "%", with: "")
                    scaleFactor = 100.0
                }
                
                strVal = strVal.trimmingCharacters(in: .whitespacesAndNewlines)
                
                guard let val = Double(strVal) else {
                    return nil
                }
                return CGFloat(val / scaleFactor)
        }
        
        guard components.count >= 3, components[0] != nil, components[1] != nil, components[2] != nil else {
            return nil
        }
        
        var color = (r: CGFloat(0.0), g: CGFloat(0.0), b: CGFloat(0.0), a: CGFloat(1.0))
        
        color.r = (components[0] ?? 0)
        color.g = (components[1] ?? 0)
        color.b = (components[2] ?? 0)
        
        // rgba values come in with `a` as a 0-1 value
        // therefore, the code above will have scaled it by /255.
        // so here we are *255 to get it back to 0-1 scale.
        if components.count >= 4 {
            color.a = (components[3] ?? 255.0) * 255
        }
        
        return UIColor(red: color.r, green: color.g, blue: color.b, alpha: color.a)
    }
    
    private static func scanHexColorStr(_ strVal: String) -> UIColor? {
        let cleanedStr = strVal
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt32 = 0
        let length = cleanedStr.count
        
        let scanner = Scanner(string: cleanedStr)
        guard scanner.scanHexInt32(&rgb) else { return nil }
        guard scanner.isAtEnd else { return nil }
        
        var color = (r: CGFloat(0.0), g: CGFloat(0.0), b: CGFloat(0.0), a: CGFloat(1.0))
        
        if length == 6 {
            color.r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            color.g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            color.b = CGFloat(rgb & 0x0000FF) / 255.0
        } else if length == 8 {
            color.r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            color.g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            color.b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            color.a = CGFloat(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }
        return UIColor(red: color.r, green: color.g, blue: color.b, alpha: color.a)
    }
}
