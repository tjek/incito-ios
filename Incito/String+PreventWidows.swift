//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

extension String {
    var withoutWidows: String {
        
        let nonBreakingSpace = "\u{00a0}" // the unicode representation of a non-breaking space
        
        var result = ""
        
        // for each paragraph
        self.enumerateSubstrings(
            in: self.startIndex..<self.endIndex,
            options: [.byParagraphs, .substringNotRequired])
        { (_, _, enclosingRange, _) in
            let fullSubstring = self[enclosingRange]
            
            // search for last normal space in paragraph
            if let lastSpaceRange = fullSubstring.range(of: " ", options: [.backwards]) {
                result += fullSubstring.replacingCharacters(in: lastSpaceRange, with: nonBreakingSpace)
            } else {
                result += fullSubstring
            }
        }
        return result
    }
}
