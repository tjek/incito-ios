///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

import XCTest
@testable import Incito

class ColorUtilsTests: XCTestCase {

    func testColorDecode() {
        
        let strVals: [(String, UIColor?)] = [
            ("rgba(10, 20, 255, 1)", UIColor(red: 10/255, green: 20/255, blue: 255/255, alpha: 1.0)),
            ("rgb(0, 10, 10%, 0.1)", UIColor(red: 0/255, green: 10/255, blue: 10/100, alpha: 0.1)),
            ("rGba(12 %, 15%, 0.5)", UIColor(red: 12/100, green: 15/100, blue: 0.5/255, alpha: 1.0)),
            ("rgb 100, 25, 22)", nil),
            ("rgb(100, 25, 22)", UIColor(red: 100/255, green: 25/255, blue: 22/255, alpha: 1)),
            ("#FFFFFF", UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1)),
            ("#ABCAAA", UIColor(red: 171/255, green: 202/255, blue: 170/255, alpha: 1)),
            ("#12DEFF12", UIColor(red: 18/255, green: 222/255, blue: 255/255, alpha: 18/255)),
            ("#XXXXXXXX", nil),
            ("12312369", UIColor(red: 18/255, green: 49/255, blue: 35/255, alpha: 105/255)),
            ]

        for (str, expectedColor) in strVals {
            let color = UIColor(webString: str)
            XCTAssertEqual(color, expectedColor)
        }
    }
}
