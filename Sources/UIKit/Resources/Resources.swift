//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import Foundation

struct Assets {
    struct ErrorView {
        static var retryButton: String {
            return localizedString("Try Again")
        }
    }
}

fileprivate func localizedString(_ key: String) -> String {
    return NSLocalizedString(key,
                             tableName: "Incito",
                             bundle: .incito,
                             comment: "")
}
