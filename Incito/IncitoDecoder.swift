//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

func decodeIncito(_ filename: String) -> Incito {
    
    do {
        let jsonFile = Bundle.main.url(forResource: filename, withExtension: nil)
        
        let jsonData = try Data(contentsOf: jsonFile!)
        let start = Date.timeIntervalSinceReferenceDate
        let incito = try JSONDecoder().decode(Incito.self, from: jsonData)
        let end = Date.timeIntervalSinceReferenceDate
        print("Decoding \(Double(jsonData.count) / 1024 / 1024)mb json in \(round((end - start) * 1000))ms")
        return incito
    } catch {
        print(error)
        fatalError()
    }
}
