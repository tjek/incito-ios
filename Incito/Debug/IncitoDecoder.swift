//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

func decodeIncito(_ filename: String) -> IncitoPropertiesDocument {
    
    do {
        let jsonFile = Bundle.main.url(forResource: filename, withExtension: nil)
        
        let jsonData = try Data(contentsOf: jsonFile!)
        let start = Date.timeIntervalSinceReferenceDate
        let incito = try JSONDecoder().decode(IncitoDocument.self, from: jsonData)
        let end = Date.timeIntervalSinceReferenceDate
        print(" ⇢ 🤖 Decoded JSON document: \(String(format:"%.2f", Double(jsonData.count) / 1024 / 1024)) Mb in \(round((end - start) * 1000))ms")
        return incito
    } catch {
        print(error)
        fatalError()
    }
}
