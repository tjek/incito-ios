///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

import Foundation

struct Assets {
    struct ErrorView {
        static var defaultTitle: String {
            return localizedString("Unable to Load")
        }
        
        static var defaultMessage: String {
            return localizedString("Sorry, there was a problem. Please try again.")
        }

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
