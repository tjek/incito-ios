///
///  Copyright (c) 2019 Tjek. All rights reserved.
///

import Foundation
import UIKit

public struct IncitoEnvironment {
    /// A list of all the incito schema versions supported by this library.
    public static let supportedVersions: [String] = ["1.0.0"]
}

public struct IncitoDocument {

    public struct Element {
        public typealias Identifier = String
        
        public var id: Identifier
        public var role: String?
        public var meta: [String: JSONValue] = [:]
        public var featureLabels: [String] = []
        public var link: URL?
        public var title: String?
    }
    
    public typealias Identifier = String
    
    public var id: Identifier
    public var version: String
    public var backgroundColor: UIColor? = nil
    public var meta: [String: JSONValue] = [:]
    public var locale: String?
    public var elements: [Element] = []
    
    public var json: String
}
