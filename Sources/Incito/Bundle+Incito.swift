///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

import Foundation

/// A nice way to reference the current `.incito` bundle
private class IncitoReferenceClass { }

extension Bundle {
    @objc
    public static var incito: Bundle {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle(for: IncitoReferenceClass.self)
        #endif
    }
}
