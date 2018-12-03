//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import XCTest
@testable import Incito

class DecodableTests: XCTestCase {

    func testColor() {
        
        let strVals: [(String, Color?)] = [
            ("rgba(10, 20, 255, 1)", Color(r: 10/255, g: 20/255, b: 255/255, a: 1.0)),
            ("rgb(0, 10, 10%, 0.1)", Color(r: 0/255, g: 10/255, b: 10/100, a: 0.1)),
            ("rGba(12 %, 15%, 0.5)", Color(r: 12/100, g: 15/100, b: 0.5/255, a: 1.0)),
            ("rgb 100, 25, 22)", nil),
            ("rgb(100, 25, 22)", Color(r: 100/255, g: 25/255, b: 22/255, a: 1)),
            ("#FFFFFF", Color(r: 255/255, g: 255/255, b: 255/255, a: 1)),
            ("#ABCAAA", Color(r: 171/255, g: 202/255, b: 170/255, a: 1)),
            ("#12DEFF12", Color(r: 18/255, g: 222/255, b: 255/255, a: 18/255)),
            ("#XXXXXXXX", nil),
            ("12312369", Color(r: 18/255, g: 49/255, b: 35/255, a: 105/255)),
            ]

        for (str, expectedColor) in strVals {
            let color = Color(string: str)
            
            assert(color == expectedColor)
        }
    }
}
